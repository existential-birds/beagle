# Example Tutorial: Weather API Integration

This is a complete example tutorial demonstrating all principles from the tutorial-docs skill.

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
