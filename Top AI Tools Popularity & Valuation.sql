/*
Datase: Top AI Tools: Popularity & Valuation
Source: https://www.kaggle.com/datasets/ardayavuzkeskin/top-ai-tools-popularity-and-valuation
*/


/*
Questions: What are the top AI tools by popularity and valuation?
- Identify the most popularity AI tools and valuation
- Focuses on Popularity and Valuation of AI Tools (remove nulls)
- Why? Highlight shows which AI tools are gaining the most traction and recognition among users.

*/

-- Row count
SELECT COUNT(*) AS row_count FROM ai_tools;

-- Numeric coverage (how many rows have both popularity & valuation)
SELECT
  COUNT(*) AS total_rows,
  COUNT(popularity_score_110) AS with_popularity,
  COUNT(estimated_valuation_billion_usd) AS with_valuation
FROM ai_tools;

-- Top 10 by popularity
SELECT
    ai_name, 
    developer_company, 
    ai_type, release_year,
    popularity_score_110
FROM 
    ai_tools
WHERE
    popularity_score_110 IS NOT NULL
ORDER BY 
    popularity_score_110 DESC 
LIMIT 10;

/*
Here 's the breakdown of the top 10 AI tools by popularity:
ChatGPT (OpenAI) is #1 with the highest popularity score.
Other highly popular tools include DALL·E, Gemini, Claude, Midjourney, and Bard.
Popularity shows which AI tools users love and adopt the most.

RESULTS 
=======

[
  {
    "ai_name": "ChatGPT",
    "developer_company": "OpenAI",
    "ai_type": "Chatbot",
    "release_year": "2022",
    "popularity_score_110": "10.000000"
  },
  {
    "ai_name": "Midjourney",
    "developer_company": "Midjourney",
    "ai_type": "Image Generator",
    "release_year": "2022",
    "popularity_score_110": "9.000000"
  },
  {
    "ai_name": "Gemini",
    "developer_company": "Google DeepMind",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "popularity_score_110": "8.500000"
  },
  {
    "ai_name": "Claude",
    "developer_company": "Anthropic",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "popularity_score_110": "8.500000"
  },
  {
    "ai_name": "DALL·E",
    "developer_company": "OpenAI",
    "ai_type": "Image Generator",
    "release_year": "2021",
    "popularity_score_110": "8.500000"
  },
  {
    "ai_name": "Stable Diffusion",
    "developer_company": "Stability AI",
    "ai_type": "Image Generator",
    "release_year": "2022",
    "popularity_score_110": "8.000000"
  },
  {
    "ai_name": "Copilot",
    "developer_company": "Microsoft",
    "ai_type": "Coding Assistant",
    "release_year": "2023",
    "popularity_score_110": "8.000000"
  },
  {
    "ai_name": "DeepSeek",
    "developer_company": "DeepSeek AI",
    "ai_type": "Chatbot",
    "release_year": "2024",
    "popularity_score_110": "7.500000"
  },
  {
    "ai_name": "Bard (Old)",
    "developer_company": "Google",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "popularity_score_110": "7.500000"
  },
  {
    "ai_name": "Character.AI",
    "developer_company": "Character Technologies",
    "ai_type": "Chatbot",
    "release_year": "2022",
    "popularity_score_110": "7.500000"
  }
]

*/

-- Top 10 by valuation
SELECT
    ai_name, 
    developer_company, 
    ai_type, release_year,
    estimated_valuation_billion_usd
FROM 
    ai_tools
WHERE
    estimated_valuation_billion_usd IS NOT NULL
ORDER BY 
    estimated_valuation_billion_usd DESC 
LIMIT 10;


/*
Here 's the breakdown of the top 10 AI tools by valuation:
OpenAI (ChatGPT, DALL·E) leads at ~$85B.
Gemini (Google DeepMind), Grok (xAI), and Claude (Anthropic) follow with ~$15B–$4.5B.
Valuation shows where the market puts the most financial confidence.
Together, they highlight which AI tools are both widely recognized and highly valued.

RESULTS 
=======

[
  {
    "ai_name": "DALL·E",
    "developer_company": "OpenAI",
    "ai_type": "Image Generator",
    "release_year": "2021",
    "estimated_valuation_billion_usd": "85.000000"
  },
  {
    "ai_name": "ChatGPT",
    "developer_company": "OpenAI",
    "ai_type": "Chatbot",
    "release_year": "2022",
    "estimated_valuation_billion_usd": "85.000000"
  },
  {
    "ai_name": "Gemini",
    "developer_company": "Google DeepMind",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "estimated_valuation_billion_usd": "15.000000"
  },
  {
    "ai_name": "Grok",
    "developer_company": "xAI",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "estimated_valuation_billion_usd": "15.000000"
  },
  {
    "ai_name": "Bard (Old)",
    "developer_company": "Google",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "estimated_valuation_billion_usd": "15.000000"
  },
  {
    "ai_name": "LLaMA",
    "developer_company": "Meta",
    "ai_type": "LLM",
    "release_year": "2023",
    "estimated_valuation_billion_usd": "10.000000"
  },
  {
    "ai_name": "Claude",
    "developer_company": "Anthropic",
    "ai_type": "Chatbot",
    "release_year": "2023",
    "estimated_valuation_billion_usd": "4.500000"
  },
  {
    "ai_name": "Stable Diffusion",
    "developer_company": "Stability AI",
    "ai_type": "Image Generator",
    "release_year": "2022",
    "estimated_valuation_billion_usd": "4.000000"
  },
  {
    "ai_name": "Notion AI",
    "developer_company": "Notion",
    "ai_type": "Productivity",
    "release_year": "2023",
    "estimated_valuation_billion_usd": "2.000000"
  },
  {
    "ai_name": "Jasper",
    "developer_company": "Jasper AI",
    "ai_type": "Marketing",
    "release_year": "2021",
    "estimated_valuation_billion_usd": "1.750000"
  }
]

*/