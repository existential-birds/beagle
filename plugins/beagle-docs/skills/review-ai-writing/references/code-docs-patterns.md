# Code Documentation Patterns

Detecting AI-generated writing in developer documentation: docstrings, code comments, commit messages, and PR descriptions.

> **Overlap note:** Tautological docstrings and obvious comments also appear in `beagle-core:llm-artifacts-detection` (style-criteria.md). This file focuses on the AI writing style aspect; the artifacts skill focuses on unnecessary code artifacts.

---

## 1. Tautological Docstrings

### What to Look For

Docstrings that restate the function name, parameters, or signature without adding any information a developer couldn't already read from the code. The docstring is a mirror of the declaration, not a supplement to it.

Common tells:
- Docstring is the function name split into words
- Describes the return value using only the return type
- Begins with a verb form of the function name ("Gets", "Sets", "Returns", "Creates")

### Examples

**Python**

```python
# BAD - restates the function name
def get_user(user_id: int) -> User:
    """Gets the user."""
    return db.query(User).filter_by(id=user_id).one()

def __init__(self, config: Config):
    """Initializes the class."""
    self.config = config

def get_count(self) -> int:
    """Returns the count."""
    return self._count

# GOOD - adds information not in the signature
def get_user(user_id: int) -> User:
    """Raises NoResultFound if the user does not exist."""
    return db.query(User).filter_by(id=user_id).one()

def __init__(self, config: Config):
    """Starts background sync if config.auto_sync is enabled."""
    self.config = config
    if config.auto_sync:
        self._start_sync()

# GOOD - trivial function, no docstring needed
def get_count(self) -> int:
    return self._count
```

**TypeScript**

```typescript
// BAD - restates the function name
/** Gets the user by ID. */
function getUserById(id: string): User {
  return users.get(id);
}

/** Creates a new order. */
function createOrder(items: CartItem[]): Order {
  return orderService.create(items);
}

// GOOD - explains non-obvious behavior
/** Falls back to guest user if ID is not found. */
function getUserById(id: string): User {
  return users.get(id) ?? GUEST_USER;
}

// GOOD - no doc needed for clear functions
function createOrder(items: CartItem[]): Order {
  return orderService.create(items);
}
```

**fix_safety:** Safe. Removing a tautological docstring or replacing it with useful content does not change behavior.

---

## 2. Narrating Obvious Code

### What to Look For

Comments that describe what the code does line-by-line rather than explaining why. These read like a narration of the syntax rather than a note from one developer to another. They add vertical noise without aiding comprehension.

Common tells:
- Comment restates the operation: `# Loop through items`, `# Check if valid`
- Comment names the construct: `# Return the result`, `# Set the variable`
- Every block has a comment even when the code is self-documenting

### Examples

**Python**

```python
# BAD - narrates each line
def process_orders(orders: list[Order]) -> list[Receipt]:
    # Initialize results list
    results = []
    # Loop through orders
    for order in orders:
        # Check if order is valid
        if order.is_valid():
            # Process the order
            receipt = order.process()
            # Add receipt to results
            results.append(receipt)
    # Return the results
    return results

# GOOD - comment only where non-obvious
def process_orders(orders: list[Order]) -> list[Receipt]:
    results = []
    for order in orders:
        if order.is_valid():
            # process() is idempotent; safe to retry on partial failures
            receipt = order.process()
            results.append(receipt)
    return results
```

**JavaScript**

```javascript
// BAD - narrates obvious DOM operations
function renderList(items) {
  // Get the container element
  const container = document.getElementById("list");
  // Clear existing content
  container.innerHTML = "";
  // Iterate over items
  items.forEach((item) => {
    // Create a new list item
    const li = document.createElement("li");
    // Set the text content
    li.textContent = item.name;
    // Append to container
    container.appendChild(li);
  });
}

// GOOD - no comments needed; code is clear
function renderList(items) {
  const container = document.getElementById("list");
  container.innerHTML = "";
  items.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = item.name;
    container.appendChild(li);
  });
}
```

**fix_safety:** Safe. Removing narration comments does not change behavior. Keep any comment that explains a non-obvious decision or constraint.

---

## 3. "This noun verbs" Pattern

### What to Look For

Docstrings and descriptions that start with "This function...", "This method...", "This class...", "This module...". This is a signature AI sentence structure rarely used by human developers. Humans typically write in imperative mood ("Calculate totals") or start with the subject of the action ("Totals are calculated..."), not with a self-referential "This".

Common tells:
- "This function calculates..."
- "This method returns..."
- "This class represents..."
- "This module provides..."
- "This component renders..."
- "This hook manages..."

### Examples

**Python**

```python
# BAD - "This function/class/method" pattern
class OrderProcessor:
    """This class represents an order processor that handles
    the processing of customer orders."""

    def calculate_total(self, items: list[Item]) -> Decimal:
        """This method calculates the total price for the given items."""
        return sum(item.price * item.quantity for item in items)

    def apply_discount(self, total: Decimal, code: str) -> Decimal:
        """This function applies a discount code to the total."""
        discount = self.discounts.get(code, Decimal("0"))
        return total - discount

# GOOD - imperative mood, no self-reference
class OrderProcessor:
    """Process customer orders with discount and tax support."""

    def calculate_total(self, items: list[Item]) -> Decimal:
        """Sum of price * quantity across all items."""
        return sum(item.price * item.quantity for item in items)

    def apply_discount(self, total: Decimal, code: str) -> Decimal:
        """Subtract the discount for `code`. Unknown codes are ignored."""
        discount = self.discounts.get(code, Decimal("0"))
        return total - discount
```

**TypeScript**

```typescript
// BAD - "This component/hook" pattern
/**
 * This component renders a user profile card with the user's
 * avatar, name, and bio information.
 */
function ProfileCard({ user }: { user: User }) {
  return <Card>...</Card>;
}

/**
 * This hook manages the authentication state for the application.
 */
function useAuth(): AuthState {
  // ...
}

// GOOD - direct description
/** User profile card showing avatar, name, and bio. */
function ProfileCard({ user }: { user: User }) {
  return <Card>...</Card>;
}

/** Authentication state with login, logout, and token refresh. */
function useAuth(): AuthState {
  // ...
}
```

**fix_safety:** Safe. Rewriting a docstring from "This function does X" to imperative or direct style does not change behavior.

---

## 4. Exhaustive Enumeration

### What to Look For

Documentation that exhaustively lists every parameter, return value, and exception even when most are obvious from the type signature. AI models tend to produce complete Args/Returns/Raises blocks as boilerplate regardless of whether the information is useful. The result is a docstring longer than the function body that a developer will skip entirely.

Common tells:
- Args section where every description is "The [param name]" or "The [param name] to use"
- Returns section that restates the return type hint
- Raises section listing only the obvious (`ValueError` for bad input)
- Docstring is longer than the function body

### Examples

**Python**

```python
# BAD - exhaustive enumeration of obvious params
def send_notification(
    user_id: int,
    message: str,
    channel: Channel = Channel.EMAIL,
) -> bool:
    """Send a notification to a user.

    Args:
        user_id: The ID of the user to notify.
        message: The notification message to send.
        channel: The channel to send the notification through.
            Defaults to Channel.EMAIL.

    Returns:
        bool: True if the notification was sent successfully,
            False otherwise.

    Raises:
        ValueError: If user_id is invalid.
        ConnectionError: If the notification service is unavailable.
    """
    ...

# GOOD - document only non-obvious aspects
def send_notification(
    user_id: int,
    message: str,
    channel: Channel = Channel.EMAIL,
) -> bool:
    """Send a notification. Returns False if delivery is deferred
    (e.g., user has DND enabled) rather than raising."""
    ...
```

**TypeScript**

```typescript
// BAD - JSDoc repeats what the types already say
/**
 * Fetches paginated results from the API.
 *
 * @param endpoint - The API endpoint to fetch from.
 * @param page - The page number to fetch.
 * @param pageSize - The number of items per page.
 * @returns A promise that resolves to an array of results.
 * @throws {ApiError} If the request fails.
 */
async function fetchPage<T>(
  endpoint: string,
  page: number,
  pageSize: number
): Promise<T[]> {
  // ...
}

// GOOD - only document what types don't convey
/**
 * Fetch a page of results. Uses cursor-based pagination under
 * the hood; `page` is translated to a cursor internally.
 */
async function fetchPage<T>(
  endpoint: string,
  page: number,
  pageSize: number
): Promise<T[]> {
  // ...
}
```

**fix_safety:** Needs review. Removing parameter documentation is safe for obvious params, but verify that no non-obvious constraints or side effects are documented in the verbose block before trimming. Keep docs for params with subtle semantics (units, boundaries, format expectations).

---

## Review Questions

When evaluating code documentation for these patterns, ask:

1. Does this docstring tell me something the signature does not?
2. Does this comment explain why, or just restate what?
3. Would a human developer actually write "This function..." in a docstring?
4. Is this Args/Returns/Raises block earning its vertical space?
5. If I deleted this documentation, would any developer be worse off?
