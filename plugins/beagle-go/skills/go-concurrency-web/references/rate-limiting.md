# Rate Limiting

## Token Bucket Algorithm

`golang.org/x/time/rate` implements a token bucket rate limiter:

- A bucket holds up to **burst** tokens
- Tokens are added at a rate of **rps** (requests per second)
- Each request consumes one token
- If no tokens are available, the request is rejected (or waits)

Example: `rate.NewLimiter(10, 20)` allows 10 requests/second sustained with bursts up to 20.

## Global Rate Limiting

Protect the entire service from being overwhelmed:

```go
// Rate limit middleware using x/time/rate
func RateLimit(rps float64, burst int) func(http.Handler) http.Handler {
    limiter := rate.NewLimiter(rate.Limit(rps), burst)

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            if !limiter.Allow() {
                w.Header().Set("Retry-After", "1")
                http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}

// Usage
mux := http.NewServeMux()
mux.HandleFunc("GET /api/data", s.handleGetData)
handler := RateLimit(100, 200)(mux) // 100 rps, burst of 200
```

## Per-IP Rate Limiting

Prevent individual clients from monopolizing resources:

```go
// Per-IP rate limiting
type IPRateLimiter struct {
    mu       sync.RWMutex
    limiters map[string]*rate.Limiter
    rps      float64
    burst    int
}

func NewIPRateLimiter(rps float64, burst int) *IPRateLimiter {
    return &IPRateLimiter{
        limiters: make(map[string]*rate.Limiter),
        rps:      rps,
        burst:    burst,
    }
}

func (l *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
    l.mu.RLock()
    limiter, exists := l.limiters[ip]
    l.mu.RUnlock()

    if exists {
        return limiter
    }

    l.mu.Lock()
    defer l.mu.Unlock()

    // Double-check after acquiring write lock
    if limiter, exists = l.limiters[ip]; exists {
        return limiter
    }

    limiter = rate.NewLimiter(rate.Limit(l.rps), l.burst)
    l.limiters[ip] = limiter
    return limiter
}
```

### Per-IP Middleware

```go
func PerIPRateLimit(rps float64, burst int, trustProxy bool) func(http.Handler) http.Handler {
    limiter := NewIPRateLimiter(rps, burst)

    // Start cleanup goroutine
    go limiter.cleanup(5 * time.Minute)

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ip := extractIP(r, trustProxy)
            if !limiter.GetLimiter(ip).Allow() {
                w.Header().Set("Retry-After", "1")
                http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}

// extractIP returns the client IP address from the request.
// WARNING: X-Forwarded-For and X-Real-IP headers can be spoofed by clients.
// Only trust these headers when behind a known reverse proxy that strips/overwrites them.
func extractIP(r *http.Request, trustProxy bool) string {
    if trustProxy {
        // Check X-Forwarded-For for proxied requests
        if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
            // Take the first IP (client IP)
            if idx := strings.Index(xff, ","); idx != -1 {
                return strings.TrimSpace(xff[:idx])
            }
            return strings.TrimSpace(xff)
        }
        // Check X-Real-IP
        if xri := r.Header.Get("X-Real-IP"); xri != "" {
            return xri
        }
    }
    // Fall back to RemoteAddr
    host, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return r.RemoteAddr
    }
    return host
}
```

## Cleaning Up Stale Limiters

Without cleanup, the limiter map grows indefinitely. Remove entries that haven't been used recently:

```go
type trackedLimiter struct {
    limiter  *rate.Limiter
    lastSeen time.Time
}

type IPRateLimiter struct {
    mu       sync.RWMutex
    limiters map[string]*trackedLimiter
    rps      float64
    burst    int
}

func (l *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
    l.mu.RLock()
    tracked, exists := l.limiters[ip]
    l.mu.RUnlock()

    if exists {
        // Update last seen time under write lock
        l.mu.Lock()
        tracked.lastSeen = time.Now()
        l.mu.Unlock()
        return tracked.limiter
    }

    l.mu.Lock()
    defer l.mu.Unlock()

    // Double-check
    if tracked, exists = l.limiters[ip]; exists {
        tracked.lastSeen = time.Now()
        return tracked.limiter
    }

    limiter := rate.NewLimiter(rate.Limit(l.rps), l.burst)
    l.limiters[ip] = &trackedLimiter{
        limiter:  limiter,
        lastSeen: time.Now(),
    }
    return limiter
}

func (l *IPRateLimiter) cleanup(maxAge time.Duration) {
    ticker := time.NewTicker(maxAge)
    defer ticker.Stop()

    for range ticker.C {
        l.mu.Lock()
        cutoff := time.Now().Add(-maxAge)
        for ip, tracked := range l.limiters {
            if tracked.lastSeen.Before(cutoff) {
                delete(l.limiters, ip)
            }
        }
        l.mu.Unlock()
    }
}
```

## Rate Limiting by API Key or User

For authenticated endpoints, rate limit by user identity instead of IP:

```go
type KeyRateLimiter struct {
    mu       sync.RWMutex
    limiters map[string]*trackedLimiter
    tiers    map[string]Tier // API key -> tier
}

type Tier struct {
    RPS   float64
    Burst int
}

var defaultTiers = map[string]Tier{
    "free":       {RPS: 10, Burst: 20},
    "pro":        {RPS: 100, Burst: 200},
    "enterprise": {RPS: 1000, Burst: 2000},
}

func (l *KeyRateLimiter) GetLimiter(apiKey string) *rate.Limiter {
    l.mu.RLock()
    tracked, exists := l.limiters[apiKey]
    l.mu.RUnlock()

    if exists {
        l.mu.Lock()
        tracked.lastSeen = time.Now()
        l.mu.Unlock()
        return tracked.limiter
    }

    l.mu.Lock()
    defer l.mu.Unlock()

    if tracked, exists = l.limiters[apiKey]; exists {
        tracked.lastSeen = time.Now()
        return tracked.limiter
    }

    tier, ok := l.tiers[apiKey]
    if !ok {
        tier = defaultTiers["free"]
    }

    limiter := rate.NewLimiter(rate.Limit(tier.RPS), tier.Burst)
    l.limiters[apiKey] = &trackedLimiter{
        limiter:  limiter,
        lastSeen: time.Now(),
    }
    return limiter
}
```

### API Key Middleware

```go
func APIKeyRateLimit(keyLimiter *KeyRateLimiter) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            apiKey := r.Header.Get("X-API-Key")
            if apiKey == "" {
                http.Error(w, "missing API key", http.StatusUnauthorized)
                return
            }

            limiter := keyLimiter.GetLimiter(apiKey)
            if !limiter.Allow() {
                w.Header().Set("Retry-After", "1")
                w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%.0f", float64(limiter.Limit())))
                w.Header().Set("X-RateLimit-Remaining", "0")
                http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
                return
            }

            next.ServeHTTP(w, r)
        })
    }
}
```

## Returning Proper 429 Responses

Always include informative headers when rejecting rate-limited requests:

```go
func rateLimitResponse(w http.ResponseWriter, limiter *rate.Limiter) {
    reservation := limiter.Reserve()
    if !reservation.OK() {
        http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
        return
    }

    delay := reservation.Delay()
    reservation.Cancel() // We're rejecting, not waiting

    w.Header().Set("Retry-After", fmt.Sprintf("%.0f", delay.Seconds()+1))
    w.Header().Set("X-RateLimit-Limit", fmt.Sprintf("%.0f", float64(limiter.Limit())))
    w.Header().Set("X-RateLimit-Remaining", "0")

    w.WriteHeader(http.StatusTooManyRequests)
    json.NewEncoder(w).Encode(map[string]any{
        "error":       "rate limit exceeded",
        "retry_after": delay.Seconds(),
    })
}
```

## Combining Rate Limiters

Layer global and per-IP limits for defense in depth:

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /api/data", s.handleGetData)

// Apply per-IP first (inner), then global (outer)
handler := RateLimit(1000, 2000)(          // global: 1000 rps
    PerIPRateLimit(10, 20)(                // per-IP: 10 rps
        mux,
    ),
)
```

This ensures no single IP can use more than 10 rps, while the service overall caps at 1000 rps.
