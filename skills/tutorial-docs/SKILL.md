---
name: tutorial-docs
description: Tutorial patterns for documentation - learning-oriented guides that teach through guided doing
autoContext:
  whenUserAsks:
    - tutorial
    - tutorials
    - learning guide
    - getting started guide
    - onboarding guide
    - beginner guide
    - introductory guide
    - learn by doing
    - hands-on guide
dependencies:
  - docs-style
---

# Tutorial Documentation Skill

This skill provides patterns for writing effective tutorials following the Diataxis framework. Tutorials are learning-oriented content where the reader learns by doing under the guidance of a teacher.

## Purpose & Audience

**Target readers:**
- Complete beginners with no prior experience
- Users who want to learn, not accomplish a specific task
- People who need a successful first experience with the product
- Learners who benefit from guided, hands-on practice

**Tutorials are NOT:**
- How-To guides (which help accomplish specific tasks)
- Explanations (which provide understanding)
- Reference docs (which describe the system)

## Core Principles (Diataxis Framework)

### 1. Learn by Doing, Not by Reading

Tutorials teach through action, not explanation. The reader should be doing something at every moment.

| Avoid | Prefer |
|-------|--------|
| "REST APIs use HTTP methods to..." | "Run this command to make your first API call:" |
| "Authentication is important because..." | "Add your API key to authenticate:" |
| "The dashboard contains several sections..." | "Click **Create Project** in the dashboard." |

### 2. Deliver Visible Results at Every Step

After each action, tell readers exactly what they should see. This confirms success and builds confidence.

```markdown
Run the development server:

```bash
npm run dev
```

You should see:

```
> Local: http://localhost:3000
> Ready in 500ms
```

Open http://localhost:3000 in your browser. You should see a welcome page with "Hello, World!" displayed.
```

### 3. One Clear Path, Minimize Choices

Tutorials should not offer alternatives. Pick one way and guide the reader through it completely.

| Avoid | Prefer |
|-------|--------|
| "You can use npm, yarn, or pnpm..." | "Install the dependencies:" |
| "There are several ways to configure..." | "Create a config file:" |
| "Optionally, you might want to..." | [Omit optional steps entirely] |

### 4. The Teacher Takes Responsibility

If the reader fails, the tutorial failed. Anticipate problems and prevent them. Never blame the reader.

```markdown
<Warning>
Make sure you're in the project directory before running this command.
If you see "command not found", return to Step 2 to verify the installation.
</Warning>
```

### 5. Permit Repetition to Build Confidence

Repeating similar actions in slightly different contexts helps cement learning. Don't try to be efficient.

## Tutorial Template

Use this structure for all tutorials:

```markdown
---
title: "Build your first [thing]"
description: "Learn the basics of [product] by building a working [thing]"
---

# Build Your First [Thing]

In this tutorial, you'll build a [concrete deliverable]. By the end, you'll have a working [thing] that [does something visible].

<Note>
This tutorial takes approximately [X] minutes to complete.
</Note>

## What you'll build

[Screenshot or diagram of the end result]

A [brief description of the concrete deliverable] that:
- [Visible capability 1]
- [Visible capability 2]
- [Visible capability 3]

## Prerequisites

Before starting, make sure you have:

- [Minimal requirement 1 - link to install guide if needed]
- [Minimal requirement 2]

<Tip>
New to [prerequisite]? [Link to external resource] has a quick setup guide.
</Tip>

## Step 1: [Set up your project]

[First action - always start with something that produces visible output]

```bash
[command]
```

You should see:

```
[expected output]
```

[Brief confirmation of what this means]

## Step 2: [Create your first thing]

[Next action with clear instruction]

```code
[code to add or modify]
```

Save the file. You should see [visible change].

<Note>
[Optional tip to prevent common mistakes]
</Note>

## Step 3: [Continue building]

[Continue with more steps, each producing visible output]

## Step 4: [Add the final piece]

[Bring it together with a final step]

You should now see [final visible result].

[Screenshot of completed project]

## What you've learned

In this tutorial, you:

- [Concrete skill 1 - what they can now do]
- [Concrete skill 2]
- [Concrete skill 3]

## Next steps

Now that you have a working [thing], you can:

- **[Tutorial 2 title]** - Continue learning by [next learning goal]
- **[How-to guide]** - Learn how to [specific task] with your [thing]
- **[Concepts page]** - Understand [concept] in more depth
```

## Writing Principles

### Title Conventions

- **Start with action outcomes**: "Build your first...", "Create a...", "Deploy your..."
- Focus on what they'll make, not what they'll learn
- Be concrete: "Build a chat application" not "Learn about real-time messaging"

### Step Structure

1. **Lead with the action** - don't explain before doing
2. **Show exactly what to type or click** - no ambiguity
3. **Confirm success after every step** - "You should see..."
4. **Keep steps small** - one visible change per step

### Managing Prerequisites

Tutorials are for beginners, so minimize prerequisites:

```markdown
## Prerequisites

- A computer with macOS, Windows, or Linux
- A text editor (we recommend VS Code)
- 15 minutes of time

<Tip>
You don't need any programming experience. This tutorial explains everything as we go.
</Tip>
```

### The "You should see" Pattern

This is the most important pattern in tutorial writing. Use it constantly:

```markdown
Click **Save**. You should see a green checkmark appear next to the filename.

Run the test:

```bash
npm test
```

You should see:

```
PASS  src/app.test.js
  ✓ renders welcome message (23ms)

Tests: 1 passed, 1 total
```
```

### Handling Errors Gracefully

Anticipate failures and guide readers back on track:

```markdown
<Warning>
If you see "Module not found", make sure you saved the file from Step 2.
Return to Step 2 and verify the import statement matches exactly.
</Warning>
```

## Components for Tutorials

### Frame Component for Screenshots

Show what success looks like:

```markdown
<Frame caption="Your completed dashboard should look like this">
  ![Dashboard screenshot](/images/tutorial-dashboard.png)
</Frame>
```

### Steps Component for Procedures

For numbered sequences within a step:

```markdown
<Steps>
  <Step title="Open the settings panel">
    Click the gear icon in the top right corner.
  </Step>
  <Step title="Find the API section">
    Scroll down to **Developer Settings**.
  </Step>
  <Step title="Generate a key">
    Click **Create New Key** and copy the value shown.
  </Step>
</Steps>
```

### Callouts for Guidance

```markdown
<Note>
Don't worry if the colors look different on your screen.
We'll customize the theme in the next step.
</Note>

<Warning>
Make sure to save the file before continuing.
The next step won't work without this change.
</Warning>

<Tip>
You can press Cmd+S (Mac) or Ctrl+S (Windows) to save quickly.
</Tip>
```

### Code with Highlighted Lines

Draw attention to what matters:

```markdown
```javascript {3-4}
function App() {
  return (
    <h1>Hello, World!</h1>
    <p>Welcome to your first app.</p>
  );
}
```
```

## Example Tutorial

```markdown
---
title: "Build your first API integration"
description: "Learn the basics of our API by building a working weather dashboard"
---

# Build Your First API Integration

In this tutorial, you'll build a weather dashboard that fetches real data from our API. By the end, you'll have a working page that displays current weather for any city.

<Note>
This tutorial takes approximately 20 minutes to complete.
</Note>

## What you'll build

<Frame caption="The completed weather dashboard">
  ![Weather dashboard showing temperature and conditions](/images/weather-dashboard.png)
</Frame>

A simple weather dashboard that:
- Accepts a city name as input
- Fetches real weather data from our API
- Displays temperature and conditions

## Prerequisites

Before starting, make sure you have:

- Node.js 18 or later installed ([download here](https://nodejs.org))
- A free account ([sign up](https://example.com/signup))

## Step 1: Create your project

Open your terminal and create a new project folder:

```bash
mkdir weather-dashboard
cd weather-dashboard
npm init -y
```

You should see:

```
Wrote to /weather-dashboard/package.json
```

This creates a new project with default settings.

## Step 2: Install the SDK

Install our JavaScript SDK:

```bash
npm install @example/weather-sdk
```

You should see output ending with:

```
added 1 package in 2s
```

## Step 3: Get your API key

<Steps>
  <Step title="Open the dashboard">
    Go to [dashboard.example.com](https://dashboard.example.com) and sign in.
  </Step>
  <Step title="Navigate to API keys">
    Click **Settings** in the sidebar, then **API Keys**.
  </Step>
  <Step title="Create a key">
    Click **Create Key**, name it "weather-tutorial", and click **Generate**.
  </Step>
  <Step title="Copy the key">
    Copy the key shown. You'll need it in the next step.
  </Step>
</Steps>

<Warning>
Keep this key secret. Don't share it or commit it to version control.
</Warning>

## Step 4: Write your first API call

Create a new file called `weather.js`:

```javascript
const Weather = require('@example/weather-sdk');

const client = new Weather({
  apiKey: 'your-api-key-here'  // Replace with your key from Step 3
});

async function getWeather(city) {
  const data = await client.current(city);
  console.log(`Weather in ${city}:`);
  console.log(`  Temperature: ${data.temp}°F`);
  console.log(`  Conditions: ${data.conditions}`);
}

getWeather('San Francisco');
```

Replace `'your-api-key-here'` with the API key you copied in Step 3.

Save the file.

## Step 5: Run your dashboard

Run your script:

```bash
node weather.js
```

You should see:

```
Weather in San Francisco:
  Temperature: 62°F
  Conditions: Partly cloudy
```

You've just made your first API call.

<Note>
The temperature will vary based on current conditions.
Any valid output means your integration is working.
</Note>

## Step 6: Try another city

Change the last line of `weather.js`:

```javascript
getWeather('Tokyo');
```

Run it again:

```bash
node weather.js
```

You should see weather data for Tokyo:

```
Weather in Tokyo:
  Temperature: 75°F
  Conditions: Clear
```

## What you've learned

In this tutorial, you:

- Created a new Node.js project
- Installed and configured our SDK
- Generated an API key
- Made API calls to fetch weather data

## Next steps

Now that you have a working API integration, you can:

- **[Build a weather CLI](/tutorials/weather-cli)** - Continue learning by adding command-line arguments
- **[How to handle API errors](/how-to/handle-api-errors)** - Learn to handle rate limits and network issues
- **[API reference](/reference/weather-api)** - Explore all available weather endpoints
```

## Checklist for Tutorials

Before publishing, verify:

- [ ] Title describes what they'll build, not what they'll learn
- [ ] Introduction shows the concrete end result
- [ ] Prerequisites are minimal (beginners don't have much)
- [ ] Every step produces visible output
- [ ] "You should see" appears after each significant action
- [ ] No choices offered - one clear path only
- [ ] No explanations of why things work (save for docs)
- [ ] Potential failures are anticipated with recovery guidance
- [ ] "What you've learned" summarizes concrete skills gained
- [ ] Next steps guide to continued learning
- [ ] Tutorial tested end-to-end by someone unfamiliar with it

## When to Use Tutorial vs Other Doc Types

| User's mindset | Doc type | Example |
|---------------|----------|---------|
| "I want to learn" | **Tutorial** | "Build your first chatbot" |
| "I want to do X" | How-To | "How to configure SSO" |
| "I want to understand" | Explanation | "How our caching works" |
| "I need to look up Y" | Reference | "API endpoint reference" |

### Tutorial vs How-To: Key Differences

| Aspect | Tutorial | How-To |
|--------|----------|--------|
| **Purpose** | Learning through doing | Accomplishing a specific task |
| **Audience** | Complete beginners | Users with some experience |
| **Structure** | Linear journey with one path | Steps to achieve a goal |
| **Choices** | None - one prescribed way | May show alternatives |
| **Explanations** | Minimal - action over theory | Minimal - focus on steps |
| **Success** | Reader learns and gains confidence | Reader completes their task |
| **Length** | Longer, more hand-holding | Shorter, more direct |

## Related Skills

- **docs-style**: Core writing conventions and components
- **howto-docs**: How-To guide patterns for task-oriented content
- **reference-docs**: Reference documentation patterns
- **explanation-docs**: Conceptual documentation patterns
