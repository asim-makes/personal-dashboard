import React, { useState, useEffect } from "react";
import {
  Cloud,
  Github,
  DollarSign,
  Newspaper,
  RefreshCw,
  Settings,
  Sun,
  CloudRain,
  Wind,
  Eye,
  Plus,
  Trash2,
  Calendar,
  ExternalLink,
  Star,
  GitBranch,
  AlertCircle,
} from "lucide-react";

// Type definitions
type WeatherData = {
  location: string;
  temperature_c: number;
  country: string;
  condition: string;
//   humidity: number;
//   windSpeed: number;
//   uvIndex: number;
};

type GithubActivity = {
  id: number;
  type: string;
  repo: string;
  message: string;
  timestamp: string;
  commits?: number;
};

type Expense = {
  expenseId: number;
  description: string;
  amount: number;
  category: string;
  date: string;
};

type NewsArticle = {
  id: number;
  title: string;
  summary: string;
  source: string;
  publishedAt: string;
  url?: string;
};

type LoadingState = {
  weather: boolean;
  github: boolean;
  expenses: boolean;
  news: boolean;
};

type ErrorState = {
  weather?: string | null;
  github?: string | null;
  expenses?: string | null;
  news?: string | null;
};

type NewExpense = {
  description: string;
  amount: string;
  category: string;
};

const App: React.FC = () => {
  // API Configuration - Update these with your API Gateway endpoints
  // const API_CONFIG = {
  //   weather: {
  //     baseUrl: process.env.REACT_APP_WEATHER_GATEWAY_URL || "http://localhost:3001", // Example: A dedicated URL for the weather service
  //     endpoint: "/WeatherApp",
  //   },
  //   github: {
  //     baseUrl: process.env.REACT_APP_GITHUB_GATEWAY_URL || "http://localhost:3002", // Example: A dedicated URL for the GitHub service
  //     endpoint: "/GitHubApp",
  //   },
  //   expenses: {
  //     baseUrl: process.env.REACT_APP_EXPENSES_GATEWAY_URL || "http://localhost:3003", // Example: A dedicated URL for the expenses service
  //     endpoint: "/expenses",
  //   },
  //   news: {
  //     baseUrl: process.env.REACT_APP_NEWS_GATEWAY_URL || "http://localhost:3004", // Example: A dedicated URL for the news service
  //     endpoint: "/news",
  //   },
  // };

  const API_CONFIG = {
    weather: process.env.REACT_APP_WEATHER_GATEWAY_URL || "http://localhost:3001/weather",
    github: process.env.REACT_APP_GITHUB_GATEWAY_URL || "http://localhost:3002/github",
    expenses: process.env.REACT_APP_EXPENSES_GATEWAY_URL || "http://localhost:3003/expenses",
    news: process.env.REACT_APP_NEWS_GATEWAY_URL || "http://localhost:3004/news",
  };

  // State management
  const [weatherData, setWeatherData] = useState<WeatherData | null>(null);
  const [githubActivity, setGithubActivity] = useState<GithubActivity[]>([]);
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [selectedCategory, setSelectedCategory] = useState("all");
  const [newsData, setNewsData] = useState<NewsArticle[]>([]);
  const [loading, setLoading] = useState<LoadingState>({
    weather: false,
    github: false,
    expenses: false,
    news: false,
  });
  const [errors, setErrors] = useState<ErrorState>({});

  // New expense form state
  const [newExpense, setNewExpense] = useState<NewExpense>({
    description: "",
    amount: "",
    category: "other",
  });

  const apiCall = async (url: string, options: RequestInit = {}) => {
    try {
      const response = await fetch(url, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${localStorage.getItem("authToken") || ""}`,
          ...(options.headers as object),
        },
        ...options,
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return await response.json();
    } catch (error) {
      console.error(`API Error for ${url}:`, error);
      throw error;
    }
  };

  // Weather Functions
  const fetchWeatherData = async () => {
    setLoading((prev) => ({ ...prev, weather: true }));
    setErrors((prev) => ({ ...prev, weather: null }));

    try {
      const location = "Kathmandu";
      const data = await apiCall(API_CONFIG.weather, {
        method: "POST",
        body: JSON.stringify({ location: location }),
      });
      setWeatherData(data as WeatherData);
    } catch (error) {
      setErrors((prev) => ({
        ...prev,
        weather: "Failed to fetch weather data",
      }));
      setWeatherData({
        location: "Kathmandu",
        temperature_c: 72,
        country: "Nepal",
        condition: "Partly Cloudy"
      });
    } finally {
      setLoading((prev) => ({ ...prev, weather: false }));
    }
  };

  // GitHub Activity Functions
  const fetchGithubActivity = async () => {
    setLoading((prev) => ({ ...prev, github: true }));
    setErrors((prev) => ({ ...prev, github: null }));
    try {
      const data = await apiCall(API_CONFIG.github);
      setGithubActivity((data.recent_activity || []) as GithubActivity[]);
    } catch (error) {
      setErrors((prev) => ({
        ...prev,
        github: "Failed to fetch GitHub activity",
      }));
    } finally {
      setLoading((prev) => ({ ...prev, github: false }));
    }
  };

  // Expense Tracker Functions
  const fetchExpenses = async () => {
    setLoading((prev) => ({ ...prev, expenses: true }));
    setErrors((prev) => ({ ...prev, expenses: null }));

    try {
      const responseData = await apiCall(API_CONFIG.expenses);
      setExpenses(responseData.expenses as Expense[]);
    } catch (error) {
      console.error("Failed to fetch expenses:", error);
      setErrors((prev) => ({ ...prev, expenses: "Failed to fetch expenses" }));
      setExpenses([
        {
          expenseId: 1,
          description: "Groceries",
          amount: 85.5,
          category: "food",
          date: "2024-03-15",
        },
        {
          expenseId: 2,
          description: "Gas",
          amount: 45.0,
          category: "transport",
          date: "2024-03-14",
        },
        {
          expenseId: 3,
          description: "Netflix",
          amount: 15.99,
          category: "entertainment",
          date: "2024-03-13",
        },
      ]);
    } finally {
      setLoading((prev) => ({ ...prev, expenses: false }));
    }
  };

  // Add Expense
  const addExpense = async () => {
    // 1. Basic validation: check if fields are empty
    if (!newExpense.description || !newExpense.amount) {
      alert("Description and Amount are required.");
      return; // Stop execution if validation fails
    }

    // 2. Type validation: ensure amount is a valid number
    const amount = parseFloat(newExpense.amount);
    if (isNaN(amount) || amount <= 0) {
      alert("Please enter a valid positive amount.");
      return; // Stop execution if validation fails
    }

    try {
        const expense: Omit<Expense, "expenseId"> = {
          ...newExpense,
          amount: Math.round(amount * 100), // Use the validated 'amount' variable
          date: new Date().toISOString().split("T")[0],
        };

        const data = await apiCall(API_CONFIG.expenses, {
          method: "POST",
          body: JSON.stringify(expense),
        });

        // ... (rest of your success logic)
    } catch (error) {
        // 💡 Acknowledge the error and display it to the user.
      console.error("Failed to add expense:", error);
      setErrors((prev) => ({ ...prev, expenses: "Failed to add expense. Check the console for details." }));
      // Consider adding the expense to the state as a temporary fallback, but
      // be aware it won't be saved to the database.
      const fallbackExpense: Expense = {
        expenseId: Date.now(),
        ...newExpense,
        amount: Math.round(parseFloat(newExpense.amount) * 100),
        date: new Date().toISOString().split("T")[0],
      };
      setExpenses((prev) => [fallbackExpense, ...prev]);
      setNewExpense({ description: "", amount: "", category: "other" });
    }
  };

  // Delete Expense
  const deleteExpense = async (id: number) => {
    try {
      await apiCall(`${API_CONFIG.expenses}/${id}`, {
        method: "DELETE",
      });
      setExpenses((prev) => prev.filter((expense) => expense.expenseId !== id));
    } catch (error) {
      setExpenses((prev) => prev.filter((expense) => expense.expenseId !== id));
    }
  };

  // News Feed Functions
  const fetchNews = async () => {
    setLoading((prev) => ({ ...prev, news: true }));
    setErrors((prev) => ({ ...prev, news: null }));

    try {
      const data = await apiCall(API_CONFIG.news);
      setNewsData((data.articles || []) as NewsArticle[]);
    } catch (error) {
      setErrors((prev) => ({ ...prev, news: "Failed to fetch news" }));
      setNewsData([
        {
          id: 1,
          title: "Latest Tech Developments in Cloud Computing",
          summary: "Major cloud providers announce new serverless capabilities...",
          source: "TechNews",
          publishedAt: "2024-03-15T12:00:00Z",
          url: "https://example.com/news1",
        },
        {
          id: 2,
          title: "JavaScript Frameworks: What's New in 2024",
          summary: "React, Vue, and Angular continue to evolve with new features...",
          source: "DevToday",
          publishedAt: "2024-03-15T10:30:00Z",
          url: "https://example.com/news2",
        },
      ]);
    } finally {
      setLoading((prev) => ({ ...prev, news: false }));
    }
  };

  // Initialize dashboard
  useEffect(() => {
    fetchWeatherData();
    fetchGithubActivity();
    fetchExpenses();
    fetchNews();
    // eslint-disable-next-line
  }, []);

  // Helper functions
  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat("ne-NP", {
      style: "currency",
      currency: "NPR",
    }).format(amount);
  const formatDate = (dateString: string) =>
    new Date(dateString).toLocaleDateString();
  const formatRelativeTime = (dateString: string) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInHours = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60));

    if (diffInHours < 1) return "Just now";
    if (diffInHours < 24) return `${diffInHours}h ago`;
    return `${Math.floor(diffInHours / 24)}d ago`;
  };

  const getWeatherIcon = (condition?: string) => {
    if (condition?.toLowerCase().includes("rain"))
      return <CloudRain className="w-8 h-8" />;
    if (condition?.toLowerCase().includes("cloud"))
      return <Cloud className="w-8 h-8" />;
    return <Sun className="w-8 h-8" />;
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case "push":
        return <GitBranch className="w-4 h-4" />;
      case "star":
        return <Star className="w-4 h-4" />;
      case "fork":
        return <GitBranch className="w-4 h-4" />;
      default:
        return <Github className="w-4 h-4" />;
    }
  };

  const getCategoryColor = (category: string) => {
    const colors: { [key: string]: string } = {
      food: "bg-green-100 text-green-800",
      transport: "bg-blue-100 text-blue-800",
      entertainment: "bg-purple-100 text-purple-800",
      utilities: "bg-orange-100 text-orange-800",
      other: "bg-gray-100 text-gray-800",
    };
    return colors[category] || colors.other;
  };

  // --- JSX (UI) ---
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      {/* Header */}
      <header className="backdrop-blur-sm bg-white/10 border-b border-white/20 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                <Cloud className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">
                  Personal Dashboard
                </h1>
                <p className="text-sm text-gray-300">Cloud-powered insights</p>
              </div>
            </div>
            <button className="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors">
              <Settings className="w-5 h-5" />
            </button>
          </div>
        </div>
      </header>

      {/* Dashboard Grid */}
      <main className="max-w-7xl mx-auto px-6 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
          {/* Weather Widget */}
          <div className="backdrop-blur-sm bg-white/10 rounded-2xl p-6 border border-white/20">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-white flex items-center">
                <Cloud className="w-5 h-5 mr-2" />
                Weather
              </h2>
              <button
                onClick={fetchWeatherData}
                disabled={loading.weather}
                className="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors disabled:opacity-50"
              >
                <RefreshCw
                  className={`w-4 h-4 ${loading.weather ? "animate-spin" : ""}`}
                />
              </button>
            </div>

            {errors.weather ? (
              <div className="flex items-center text-red-300 text-sm">
                <AlertCircle className="w-4 h-4 mr-2" />
                {errors.weather}
              </div>
            ) : weatherData ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-3xl font-bold text-white">
                      {weatherData.temperature_c}°C
                    </p>
                    <p className="text-gray-300">{weatherData.location}, {weatherData.country}</p>
                  </div>
                  <div className="text-white">
                    {getWeatherIcon(weatherData.condition)}
                  </div>
                </div>
                <p className="text-gray-300">{weatherData.condition}</p>
              </div>
            ) : (
              <div className="animate-pulse space-y-4">
                <div className="h-8 bg-white/10 rounded w-1/2"></div>
                <div className="h-4 bg-white/10 rounded w-3/4"></div>
                <div className="h-16 bg-white/10 rounded"></div>
              </div>
            )}
          </div>

          {/* GitHub Activity Feed */}
          <div className="backdrop-blur-sm bg-white/10 rounded-2xl p-6 border border-white/20">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-white flex items-center">
                <Github className="w-5 h-5 mr-2" />
                GitHub Activity
              </h2>
              <button
                onClick={fetchGithubActivity}
                disabled={loading.github}
                className="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors disabled:opacity-50"
              >
                <RefreshCw
                  className={`w-4 h-4 ${loading.github ? "animate-spin" : ""}`}
                />
              </button>
            </div>

            {errors.github ? (
              <div className="flex items-center text-red-300 text-sm">
                <AlertCircle className="w-4 h-4 mr-2" />
                {errors.github}
              </div>
            ) : (
              <div className="space-y-3 max-h-80 overflow-y-auto">
                {githubActivity.map((activity) => (
                  <div
                    key={activity.id}
                    className="flex items-start space-x-3 p-3 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
                  >
                    <div className="flex-shrink-0 mt-0.5 text-gray-400">
                      {getActivityIcon(activity.type)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-white font-medium">
                        {activity.repo}
                      </p>
                      <p className="text-xs text-gray-300">
                        {activity.message}
                      </p>
                      <div className="flex items-center justify-between mt-1">
                        <span className="text-xs text-gray-400">
                          {formatRelativeTime(activity.timestamp)}
                        </span>
                        {activity.commits && (
                          <span className="text-xs bg-green-500/20 text-green-300 px-2 py-0.5 rounded">
                            {activity.commits} commits
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Expense Tracker */}
          <div className="backdrop-blur-sm bg-white/10 rounded-2xl p-6 border border-white/20">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-white flex items-center">
                <DollarSign className="w-5 h-5 mr-2" />
                Expenses
              </h2>
              <button
                onClick={fetchExpenses}
                disabled={loading.expenses}
                className="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors disabled:opacity-50"
              >
                <RefreshCw
                  className={`w-4 h-4 ${
                    loading.expenses ? "animate-spin" : ""
                  }`}
                />
              </button>
            </div>

            {/* Add Expense Form */}
            <div className="mb-6 p-4 rounded-lg bg-white/5">
              <div className="grid grid-cols-1 gap-3">
                <input
                  type="text"
                  placeholder="Description"
                  value={newExpense.description}
                  onChange={(e) =>
                    setNewExpense((prev) => ({
                      ...prev,
                      description: e.target.value,
                    }))
                  }
                  className="bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white placeholder-gray-400 text-sm"
                />
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="number"
                    placeholder="Amount"
                    value={newExpense.amount}
                    onChange={(e) =>
                      setNewExpense((prev) => ({
                        ...prev,
                        amount: e.target.value,
                      }))
                    }
                    className="bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white placeholder-gray-400 text-sm"
                  />
                  <select
                    value={newExpense.category}
                    onChange={(e) =>
                      setNewExpense((prev) => ({
                        ...prev,
                        category: e.target.value,
                      }))
                    }
                    className="bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm"
                  >
                    <option value="food">Food</option>
                    <option value="transport">Transport</option>
                    <option value="entertainment">Entertainment</option>
                    <option value="utilities">Utilities</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                <button
                  onClick={addExpense}
                  className="flex items-center justify-center bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <Plus className="w-4 h-4 mr-2" />
                  Add Expense
                </button>
              </div>
            </div>

            {/* Category Filter */}
            <div className="mb-4">
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-white text-sm"
              >
                <option value="all">All Categories</option>
                <option value="food">Food</option>
                <option value="transport">Transport</option>
                <option value="entertainment">Entertainment</option>
                <option value="utilities">Utilities</option>
                <option value="other">Other</option>
              </select>
            </div>


            {/* Expenses List */}
            {errors.expenses ? (
              <div className="flex items-center text-red-300 text-sm">
                <AlertCircle className="w-4 h-4 mr-2" />
                {errors.expenses}
              </div>
            ) : (
              <div className="space-y-3 max-h-64 overflow-y-auto">
                <div className="text-right text-sm text-gray-300 mb-2">
                  Total:{" "}
                  {formatCurrency(
                    expenses
                      .filter((expense) =>
                        selectedCategory === "all"
                          ? true
                          : expense.category === selectedCategory
                      )
                      .reduce((sum, expense) => sum + expense.amount, 0)
                  )}
                </div>

                {expenses
                  .filter((expense) =>
                    selectedCategory === "all" ? true : expense.category === selectedCategory
                  )
                  .map((expense) => (
                    <div
                      key={expense.expenseId}
                      className="flex items-center justify-between p-3 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
                    >
                      <div className="flex-1">
                        <p className="text-sm font-medium text-white">{expense.description}</p>
                        <div className="flex items-center space-x-2 mt-1">
                          <span
                            className={`text-xs px-2 py-0.5 rounded ${getCategoryColor(
                              expense.category
                            )}`}
                          >
                            {expense.category}
                          </span>
                          <span className="text-xs text-gray-400">
                            {formatDate(expense.date)}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center space-x-2">
                        <span className="text-sm font-semibold text-white">
                          {formatCurrency(expense.amount / 100)}
                        </span>
                        <button
                          onClick={() => deleteExpense(expense.expenseId)}
                          className="p-1 rounded text-red-400 hover:bg-red-500/20 transition-colors"
                        >
                          <Trash2 className="w-3 h-3" />
                        </button>
                      </div>
                    </div>
                  ))}
              </div>
            )}
          </div>

          {/* News Feed */}
          <div className="backdrop-blur-sm bg-white/10 rounded-2xl p-6 border border-white/20 lg:col-span-2 xl:col-span-3">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-white flex items-center">
                <Newspaper className="w-5 h-5 mr-2" />
                Latest News
              </h2>
              <button
                onClick={fetchNews}
                disabled={loading.news}
                className="p-2 rounded-lg bg-white/10 hover:bg-white/20 text-white transition-colors disabled:opacity-50"
              >
                <RefreshCw
                  className={`w-4 h-4 ${loading.news ? "animate-spin" : ""}`}
                />
              </button>
            </div>

            {errors.news ? (
              <div className="flex items-center text-red-300 text-sm">
                <AlertCircle className="w-4 h-4 mr-2" />
                {errors.news}
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                {newsData.map((article) => (
                  <div
                    key={article.id}
                    className="p-4 rounded-lg bg-white/5 hover:bg-white/10 transition-colors"
                  >
                    <h3 className="font-semibold text-white mb-2 line-clamp-2">
                      {article.title}
                    </h3>
                    <p className="text-sm text-gray-300 mb-3 line-clamp-3">
                      {article.summary}
                    </p>
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-2">
                        <span className="text-xs text-gray-400">
                          {article.source}
                        </span>
                        <span className="text-xs text-gray-500">•</span>
                        <span className="text-xs text-gray-400">
                          {formatRelativeTime(article.publishedAt)}
                        </span>
                      </div>
                      {article.url && (
                        <a
                          href={article.url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-blue-400 hover:text-blue-300"
                        >
                          <ExternalLink className="w-4 h-4" />
                        </a>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
};

export default App;
