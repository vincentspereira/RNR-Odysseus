# Output Quality Recommendations for Odysseus

Findings and actionable recommendations for maximizing the depth, detail,
and comprehensiveness of all AI outputs: chat, agent, deep research, and
documents. Includes Ollama-specific configuration notes.

---

## Summary of Findings

### Current settings (data/settings.json)

| Setting | Current Value | Impact |
|---------|--------------|--------|
| default_model | gemma4:26b-a4b-it-q4_K_M | Good mid-tier model |
| research_max_tokens | 16384 | Adequate, could go higher |
| research_extraction_timeout_seconds | 90 | OK |
| research_planning_timeout_seconds | 90 | OK |
| research_query_timeout_seconds | 90 | OK |
| research_extraction_concurrency | 3 | Conservative, safe |
| research_run_timeout_seconds | 1800 | 30 min, generous |
| agent_max_rounds | 20 | Good |
| agent_input_token_budget | 6000 | LOW - this is the biggest bottleneck |
| search_result_count | 5 | LOW for research depth |

### Most impactful bottleneck: agent_input_token_budget = 6000

The agent's context window fed per turn is capped at 6,000 tokens. This means
the agent sees very little of the conversation history and document context
when deciding what to do. For detailed, comprehensive outputs this is the
single most important setting to raise. Your model (gemma4:26b) has a large
context window and can handle far more.

### Second bottleneck: search_result_count = 5

Deep Research fetches 5 results per query. Each research round runs 3-4
queries, so max ~15-20 unique URLs are explored per run. Raising this to 8-10
significantly increases source breadth and report quality.

---

## Recommendations by Category

---

### 1. Research Output Quality (Most Important)

The Deep Research engine in src/deep_research.py has these hardcoded parameters
that can be influenced via settings or by changing defaults:

**Parameters that drive report depth:**

| Parameter | Default | Recommended | Where to change |
|-----------|---------|-------------|-----------------|
| max_report_tokens | 8192 | 16384-32768 | Passed from settings research_max_tokens |
| max_urls_per_round | 3 | 5-8 | Hardcoded in DeepResearcher.__init__ |
| max_content_chars | 15000 | 20000-30000 | Hardcoded in DeepResearcher.__init__ |
| synthesis_window | 10 | 15-20 | Hardcoded in DeepResearcher.__init__ |
| min_rounds | 2 | 3-4 | Hardcoded in DeepResearcher.__init__ |
| FINAL_REPORT min words check | 400 | Already good | src/deep_research.py line 757 |

**Settings you can change right now in Settings > Research:**
- research_max_tokens: raise from 16384 to 32768 (or even 65536 if model supports it)
- search_result_count: raise from 5 to 8-10 in Settings > Search
- research_extraction_concurrency: raise from 3 to 5 for faster parallel reads

**Code changes for deeper research (edit src/deep_research.py):**

In DeepResearcher.__init__ around line 196-210, change these defaults:

```python
# CURRENT:
max_urls_per_round: int = 3,
max_content_chars: int = 15000,
synthesis_window: int = 10,
min_rounds: int = 2,

# RECOMMENDED for comprehensive research:
max_urls_per_round: int = 5,
max_content_chars: int = 25000,
synthesis_window: int = 15,
min_rounds: int = 3,
```

In FINAL_REPORT_PROMPT (line 127), the minimum word count check uses 400 words.
The prompt already asks for 1500+ words but the expansion threshold is low.
Change line 757 from:
```python
if len(result.split()) < 400:
```
to:
```python
if len(result.split()) < 800:
```
This forces a second expansion pass more aggressively.

**In QUERY_GEN_PROMPT (line 64), change num_queries generation:**

Line 463-465:
```python
# CURRENT:
if round_num == 1:
    num_queries = 4
    
# Round 2+:
    num_queries = 3

# RECOMMENDED (more breadth):
if round_num == 1:
    num_queries = 6
    
# Round 2+:
    num_queries = 4
```

---

### 2. Agent Context and Memory Budget

**agent_input_token_budget: 6000 is the most impactful change.**

This controls how much conversation history and document context the agent
sees per turn. At 6,000 tokens, the agent works with about 4,500 words of
context. Your model (gemma4:26b) has a 128K+ context window.

**Recommended change in Settings > Agent:**
- agent_input_token_budget: raise to 32000 or higher
- agent_input_token_hard_max: raise to 500000 (matches your model capability)

Raising this means:
- The agent remembers more of the conversation
- It reads more of the documents you attach
- It produces more contextually-aware, detailed responses
- It makes better tool-use decisions based on more context

Trade-off: Each request is slower and uses more GPU memory. Start with 32000
and raise if responses are still losing context.

---

### 3. Ollama Configuration

**Current Odysseus behavior with Ollama:**

Odysseus reads the context window size from Ollama's /v1/models endpoint
and passes it as num_ctx in the Ollama payload (src/llm_core.py line 1389).
It also passes num_predict (max tokens to generate) from the max_tokens setting.

**What Odysseus sends to Ollama per request:**
```json
{
  "model": "gemma4:26b-a4b-it-q4_K_M",
  "messages": [...],
  "stream": true,
  "options": {
    "temperature": 0.7,
    "num_predict": 8192,
    "num_ctx": <auto-detected from Ollama>
  }
}
```

**Ollama-side settings you should verify:**

1. **num_ctx (context window):** Run this to check what Ollama is using:
   ```powershell
   ollama show gemma4:26b-a4b-it-q4_K_M
   ```
   Look for "context length" in the output. If it shows 2048 or a low value,
   Ollama is silently truncating your context. To fix:
   ```powershell
   ollama run gemma4:26b-a4b-it-q4_K_M --num-ctx 32768
   ```
   Or create a Modelfile:
   ```
   FROM gemma4:26b-a4b-it-q4_K_M
   PARAMETER num_ctx 32768
   PARAMETER num_predict 8192
   PARAMETER temperature 0.7
   ```
   Then: `ollama create gemma4-large-ctx -f Modelfile`
   And set that as your default model in Odysseus.

2. **num_predict (max output tokens):** Default is 128 in many Ollama builds.
   This severely truncates responses. Make sure Odysseus is passing num_predict
   (it does, via research_max_tokens), but verify in Ollama directly:
   ```powershell
   ollama run gemma4:26b-a4b-it-q4_K_M
   /set parameter num_predict 4096
   ```

3. **Flash attention:** Enable for faster, more memory-efficient inference:
   Set OLLAMA_FLASH_ATTENTION=1 as a system environment variable before
   starting Ollama.

4. **Keep-alive:** Prevent model from unloading between requests:
   Set OLLAMA_KEEP_ALIVE=-1 (never unload) or OLLAMA_KEEP_ALIVE=30m

   In PowerShell before starting Ollama:
   ```powershell
   $env:OLLAMA_KEEP_ALIVE = "30m"
   $env:OLLAMA_FLASH_ATTENTION = "1"
   ollama serve
   ```

5. **Parallel requests:** Odysseus may send multiple concurrent requests
   (e.g., research + utility + background tasks). Set:
   ```powershell
   $env:OLLAMA_NUM_PARALLEL = "2"
   ```

**Recommended Ollama environment variables to set permanently:**

In Windows System Properties > Environment Variables (System Variables):
```
OLLAMA_KEEP_ALIVE = 30m
OLLAMA_FLASH_ATTENTION = 1
OLLAMA_NUM_PARALLEL = 2
OLLAMA_MAX_LOADED_MODELS = 2
```

---

### 4. Chat and Document Quality

**System prompt / preset for richer output:**

In Settings > Presets, create a preset with a detailed system prompt.
Apply it as default. Example:

```
You are an expert research and writing assistant with deep analytical
capabilities. When answering questions:

- Provide comprehensive, detailed responses with full explanations
- Use structured formatting with headers and subheadings when appropriate
- Include specific examples, data points, and evidence
- Explain reasoning and context, not just conclusions
- When uncertain, say so and explain the uncertainty
- For technical topics, include code examples, commands, or formulas
- For research questions, synthesize multiple perspectives
- Target response length appropriate to the question complexity:
  simple questions: 1-3 paragraphs
  analytical questions: 4-8 paragraphs with structure
  comprehensive requests: 800-2000+ words with sections

Never truncate your response. If a topic requires depth, provide it.
```

**Max tokens for chat:**

In Settings > Model Endpoints, click your Ollama endpoint and check the
"Max Tokens" field. If it is set low (e.g., 512, 1024, 2048), raise it to
4096 or 8192. This is the num_predict cap per chat response.

---

### 5. Search Provider for Research

The default SearXNG is self-hosted and requires Docker. If it is not running,
research falls back to DuckDuckGo which has rate limits and less depth.

**Recommendation:** Get a Brave Search API key (free tier: 2000 queries/month).
- Sign up at: https://brave.com/search/api/
- Add the key in Settings > Search > Brave API Key
- Set Research Search Provider to "brave" in Settings > Research

Brave returns more detailed metadata, full snippets, and fresher results
than the DuckDuckGo fallback. For serious research work this is the most
impactful external change.

---

### 6. Recommended Settings Changes (Quick Summary)

These can all be changed in the Settings UI without editing code:

| Setting | Change To | Reason |
|---------|-----------|--------|
| Settings > Agent > Input Token Budget | 32000 | Agent sees much more context |
| Settings > Agent > Input Token Hard Max | 500000 | Removes artificial cap |
| Settings > Research > Max Tokens | 32768 | Longer research reports |
| Settings > Research > Extraction Concurrency | 5 | Faster parallel URL reads |
| Settings > Search > Result Count | 8 | More sources per query |
| Settings > Search > Brave API Key | (your key) | Better search quality |
| Settings > Research > Research Search Provider | brave | Dedicated research search |

These require editing src/deep_research.py (safe, low-risk changes):

| Parameter | Line ~196 | Change To | Effect |
|-----------|-----------|-----------|--------|
| max_urls_per_round | 196 | 5 | More sources per round |
| max_content_chars | 197 | 25000 | More content extracted per page |
| synthesis_window | 202 | 15 | Synthesizes more findings at once |
| min_rounds | 201 | 3 | Always does at least 3 research rounds |
| num_queries (round 1) | 463 | 6 | Broader initial search |

These require Ollama environment variable changes:

| Variable | Value | Effect |
|----------|-------|--------|
| OLLAMA_KEEP_ALIVE | 30m | Model stays loaded between requests |
| OLLAMA_FLASH_ATTENTION | 1 | Faster, more memory-efficient |
| OLLAMA_NUM_PARALLEL | 2 | Handle concurrent requests |

---

## Priority Order

If you implement changes gradually, start here:

1. **Raise agent_input_token_budget to 32000** - biggest single improvement
2. **Set OLLAMA_KEEP_ALIVE and verify num_ctx** - prevents silent truncation
3. **Add Brave Search API key** - much better research source quality
4. **Raise research_max_tokens to 32768** - longer reports
5. **Edit src/deep_research.py defaults** - deeper research depth
6. **Create a detailed default system prompt preset** - consistent quality

---

*Analysis based on code review of src/deep_research.py, src/llm_core.py,*
*src/model_context.py, src/settings.py, and data/settings.json*
*Generated by Claude Code for Vincent S. Pereira*
