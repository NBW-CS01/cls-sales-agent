# Building Jamie's Persona - Step-by-Step Guide

## Overview
To make Jamie 2.0 sound authentically like Jamie, we need to capture and document Jamie's unique writing style, tone, and patterns. This guide outlines what Jamie needs to do to build an effective persona.

---

## What You'll Need

### Materials Required
-  5-10 actual proposals Jamie has written
-  3-5 SOWs (Statements of Work) Jamie has created
-  Any email correspondence with customers about proposals
-  1-2 hours of Jamie's time to review and provide examples
-  Access to the Swagger proposal already in S3 as a reference

### Tools Provided
- `jamie-persona.md` - Template to fill out
- `jamie-system-prompt.txt` - Will be updated based on persona
- S3 bucket to upload examples

---

## Step-by-Step Process for Jamie

### Step 1: Gather Writing Samples (30 minutes)

**What to Collect:**
1. **Winning Proposals** (3-5 examples)
   - Proposals that resulted in won business
   - Different industries/customer types if possible
   - Mix of technical and business-focused proposals

2. **Recent SOWs** (2-3 examples)
   - Statements of Work from the last 6-12 months
   - Include both large and small engagements

3. **Email Examples** (Optional but helpful)
   - Email threads where you explained technical solutions
   - Customer-facing communication about proposals

**Where to Find Them:**
- Past Google Docs/Word documents
- Email attachments
- CRM system (if proposals are stored there)
- SharePoint/OneDrive folders

**What to Do:**
```bash
# Copy them to a local folder
mkdir ~/Documents/jamie-writing-samples

# Upload to S3 for Jamie 2.0 to reference
aws s3 cp ~/Documents/jamie-writing-samples/ \
  s3://jamie2-knowledge-base-0t76l52f/proposals/ \
  --recursive \
  --profile AdministratorAccess-380414079195
```

---

### Step 2: Analyze Your Writing Style (45 minutes)

Open `/Users/nick.barton-wells/Projects/jamie2.0/jamie-persona.md` and work through each section:

#### A. Tone & Voice Analysis

**Read 2-3 of your proposals and answer:**

1. **Professional Level**
   - Do you write like talking to executives? (high-level, business outcomes)
   - Do you write technically? (architecture diagrams, technical specs)
   - Do you write conversationally? (friendly, approachable)

   **Jamie's Style:** [Pick one or describe mix: e.g., "Executive-focused with technical depth in appendices"]

2. **Formality**
   - Highly formal? ("We would be pleased to present...")
   - Business casual? ("We're excited to partner with you...")
   - Friendly? ("Let's solve this challenge together...")

   **Jamie's Style:** [Example: "Business casual - professional but approachable"]

3. **Confidence Level**
   - Assertive? ("We will deliver..." "Our solution provides...")
   - Consultative? ("We recommend..." "We suggest...")
   - Balanced? (Mix of both)

   **Jamie's Style:** [Example: "Consultative but confident"]

4. **First Person Usage**
   - Do you write "We" (company perspective)?
   - Do you write "I" (personal perspective)?
   - Do you write "Our team"?

   **Jamie's Style:** [Example: "Always 'we' and 'our team', never 'I'"]

---

#### B. Structure & Organization

**Look at how you organize proposals:**

1. **Document Structure**
   - Do you always start with Executive Summary?
   - Where do technical details go? (Early / Late / Appendix)
   - Do you lead with problem or solution?

   **Jamie's Pattern:** [Example: "Always: Exec Summary → Challenge → Solution → Timeline → Investment → Next Steps"]

2. **Section Headings**
   ```
   Examples from your proposals:
   - "Executive Summary" or "EXECUTIVE SUMMARY" or "Summary"?
   - "The Challenge" or "Customer Challenges" or "Problem Statement"?
   - "Our Approach" or "Proposed Solution" or "How We'll Help"?
   ```

   **Jamie's Style:** [Example: "Title Case, customer-focused language ('Your Challenges' not 'Problem Statement')"]

3. **Content Format**
   - Do you prefer bullet points or paragraphs?
   - Short bullets (1 line) or detailed bullets (2-3 lines)?
   - When do you use numbered lists vs bullets?

   **Jamie's Style:** [Example: "Short bullets for exec summary, detailed paragraphs for technical sections"]

4. **Length Preferences**
   - How long are your proposals typically? (5 pages? 15 pages? 30 pages?)
   - Do you prefer concise or comprehensive?

   **Jamie's Style:** [Example: "10-15 pages - comprehensive but scannable"]

---

#### C. Language Patterns

**Find Your Signature Phrases:**

1. **Opening Sentences**

   Look at how you start proposals. Examples might be:
   - "We're excited to present this proposal for..."
   - "[Customer] faces a critical challenge in..."
   - "This proposal outlines our approach to..."

   **Jamie's Openings:** [Copy 3-5 actual opening sentences from your proposals]

2. **Transition Phrases**

   How do you move between sections?
   - "Building on this foundation..."
   - "To address these challenges..."
   - "The next phase involves..."

   **Jamie's Transitions:** [List 5-10 transition phrases you commonly use]

3. **Value Proposition Style**

   How do you describe benefits?
   - "This approach delivers 40% cost savings..."
   - "You'll achieve significant cost reduction..."
   - "Benefits include reduced costs, improved efficiency..."

   **Jamie's Value Props:** [Copy 3-5 examples of how you state benefits]

4. **Call to Action / Closing**

   How do you end proposals?
   - "We look forward to partnering with you..."
   - "Next steps include..."
   - "Let's schedule a kickoff meeting to..."

   **Jamie's Closings:** [Copy 3-5 actual closing statements]

5. **Technical Language**

   - Do you use lots of acronyms? (AWS, IaC, K8s)
   - Do you spell things out first? (Infrastructure as Code (IaC))
   - Do you avoid buzzwords or embrace them?

   **Jamie's Tech Style:** [Example: "Always spell out acronyms first, avoid buzzwords like 'synergy' and 'leverage'"]

---

#### D. Formatting Conventions

**Document How You Format:**

1. **Lists**
   ```
   Your typical bullet style:
   • Like this? or
   - Like this? or
   * Like this?

   Numbered lists:
   1. Step one
   2. Step two

   Or:

   Step 1: Description
   Step 2: Description
   ```

   **Jamie's List Style:** [Show your exact format]

2. **Emphasis**
   - Do you **bold** key terms?
   - Do you use _italics_ for emphasis?
   - Do you use ALL CAPS for anything?
   - Do you use "quotes" for certain terms?

   **Jamie's Emphasis:** [Example: "Bold for section headers, italics for customer names, never ALL CAPS"]

3. **Tables**
   - When do you use tables? (Pricing? Timelines? Comparisons?)
   - How detailed are they?

   **Jamie's Table Usage:** [Example: "Always use tables for timeline/milestones and pricing breakdown"]

---

#### E. Customer Engagement Style

**How You Address Customers:**

1. **Pain Points**

   Copy 2-3 examples of how you describe customer challenges:
   ```
   Example 1: "Your current manual deployment process creates bottlenecks..."
   Example 2: "[Customer] struggles with data visibility across systems..."
   Example 3: "The lack of automation leads to frequent errors and delays..."
   ```

   **Jamie's Pattern:** [What's your approach? Empathetic? Data-driven? Problem-focused?]

2. **Benefits Presentation**

   How do you present value?
   - Quantified? ("40% reduction in deployment time")
   - Qualitative? ("Significantly faster deployments")
   - Customer outcomes? ("Your team will deploy 3x faster")

   **Jamie's Benefits Style:** [Example: "Always quantify when possible, focus on customer outcomes"]

3. **Risk Mitigation**

   Do you address risks/concerns proactively?
   ```
   Example: "To minimize disruption, we'll implement during off-peak hours..."
   Example: "Our phased approach reduces risk by validating each stage..."
   ```

   **Jamie's Risk Approach:** [Copy 2-3 examples of how you address concerns]

4. **Pricing Discussion**

   How do you present costs?
   - Detailed line items?
   - High-level investment ranges?
   - Focus on ROI vs absolute cost?

   **Jamie's Pricing Style:** [Example: "Show total investment with ROI calculation, detailed breakdown in appendix"]

---

### Step 3: Identify Signature Phrases (15 minutes)

**Instructions:**
Search your proposals for phrases you use repeatedly. These are your "voice fingerprints."

**Common Examples:**
- "We're excited to partner with..."
- "This approach enables..."
- "Building on our experience with..."
- "The key challenge facing..."

**Your Task:**
List 10-20 phrases that appear in multiple proposals.

**Where to Document:**
Add them to `jamie-persona.md` under "Common Phrases & Expressions"

---

### Step 4: Create Before/After Examples (15 minutes)

**Purpose:**
Show the AI the difference between generic writing and YOUR writing.

**Instructions:**
Take 3 generic statements and rewrite them in your style:

**Example 1:**
```
Generic: "We offer cloud migration services."

Jamie's Style: "We partner with enterprises to transform legacy infrastructure into modern, cloud-native architectures that reduce costs while improving agility."
```

**Example 2:**
```
Generic: "The project will take 3 months."

Jamie's Style: [Your version]
```

**Example 3:**
```
Generic: "We have experience in this area."

Jamie's Style: [Your version]
```

**Where to Document:**
Add to `jamie-persona.md` under "Example Transformations"

---

### Step 5: Review Swagger Proposal (10 minutes)

**Task:**
Jamie 2.0 already generated a proposal for Swagger (in `/tmp/swagger-proposal-sonnet45.txt`).

**Questions to Answer:**
1. Does it sound like you wrote it?  / 
2. What's RIGHT about it? (List 3 things)
3. What's WRONG about it? (List 3 things)
4. What specific changes would make it more "Jamie"?

**Example Feedback:**
```
 RIGHT:
- Good structure with clear sections
- Professional tone
- Strong value proposition

 WRONG:
- Too formal ("We would be pleased to present" - I'd say "We're excited to partner")
- Missing my typical opening about customer's business context
- Benefits section too generic - I always include specific metrics

CHANGES NEEDED:
- Start with customer's industry and business model
- Use "We're excited to" instead of "We are pleased to"
- Always quantify benefits (not "significant savings" but "40-60% cost reduction")
```

**Where to Document:**
Add to `jamie-persona.md` under "Notes" section

---

## Step 6: Update the System Prompt (Optional)

Once Jamie completes the persona document, we can update the system prompt to include these specific instructions.

**File:** `/Users/nick.barton-wells/Projects/jamie2.0/prompts/jamie-system-prompt.txt`

**What Will Change:**
The section that currently says:
```
## Jamie's Writing Style
[NOTE: This section should be populated with Jamie's actual writing characteristics]
```

Will be replaced with:
```
## Jamie's Writing Style

### Tone & Voice
- [Jamie's documented tone]
- [Jamie's formality level]
- [First person usage rules]

### Structure
- Always start with: [Jamie's structure]
- Section headings: [Jamie's style]
- Use bullet points: [Jamie's preferences]

### Signature Phrases
Use these phrases naturally:
- "[Phrase 1]"
- "[Phrase 2]"
etc.
```

**Action Required:**
After Jamie completes persona document, run:
```bash
cd /Users/nick.barton-wells/Projects/jamie2.0
# Update system prompt based on persona
# Deploy to Bedrock Agent
terraform apply -auto-approve
aws bedrock-agent prepare-agent --agent-id LUZWQYYBP4 \
  --profile AdministratorAccess-380414079195 --region eu-west-2
```

---

## Quick Start Checklist for Jamie

- [ ] **Day 1: Gather Samples** (30 min)
  - Collect 5-10 proposals from past projects
  - Upload to S3 knowledge base

- [ ] **Day 2: Analyze Style** (45 min)
  - Complete tone & voice section
  - Document structure preferences
  - Identify language patterns

- [ ] **Day 3: Document Details** (30 min)
  - List signature phrases
  - Create before/after examples
  - Review Swagger proposal and provide feedback

- [ ] **Day 4: Test & Refine** (30 min)
  - Generate a test proposal with Jamie 2.0
  - Compare to what you would write
  - Document differences
  - Iterate on persona

---

## Example: Completed Section

Here's what a completed section might look like:

```markdown
### Tone & Voice

**Professional Level:** Executive-focused with technical depth
- I write primarily for C-level and VP-level decision makers
- Business outcomes and value propositions come first
- Technical details are included but in later sections or appendices
- I assume reader has business knowledge but may not be deeply technical

**Formality:** Business casual
- Professional but approachable
- Use "we're excited" not "we would be pleased"
- Use contractions naturally (we'll, you'll, it's)
- Avoid overly formal language like "herewith" or "aforementioned"

**Confidence Level:** Consultative confidence
- I recommend solutions, not just present options
- I explain *why* this approach works, not just *what* we'll do
- I acknowledge risks but show mitigation strategies
- I use "will deliver" not "should deliver" or "might deliver"

**First Person Usage:** Always "we" and "our team"
- Never "I" in proposals (too personal)
- "We" refers to the company/team
- "Our team" when emphasizing experience
- "You" and "your team" when addressing customer
```

---

## Time Investment Summary

**Total Time Required from Jamie:** ~2-3 hours spread across a few days

| Activity | Time | Priority |
|----------|------|----------|
| Gather samples | 30 min | High |
| Analyze style | 45 min | High |
| Document patterns | 30 min | High |
| Review & feedback | 30 min | Medium |
| Test & iterate | 30 min | Medium |

**Return on Investment:**
- Every proposal Jamie generates with AI saves 2-4 hours
- Persona building takes 3 hours once
- After 2-3 proposals generated, time saved exceeds time invested

---

## Support & Questions

**If you need help:**
1. Examples of what to write are in the template (`jamie-persona.md`)
2. The Swagger proposal can serve as a baseline to critique
3. Patrick/Sharona can help gather old proposals if needed

**Remember:**
- There are no wrong answers - this is about capturing YOUR style
- Be specific with examples (better than general descriptions)
- It's okay if your style varies - document the patterns
- This is a living document - update it as you review AI outputs

---

## Next Steps After Completion

Once Jamie completes the persona document:

1.  Review persona with Patrick/Sharona
2.  Update system prompt with specific style guidelines
3.  Deploy updated agent to AWS
4.  Generate 2-3 test proposals
5.  Compare outputs to Jamie's actual writing
6.  Iterate and refine persona as needed

**Goal:** Jamie 2.0 outputs should be 80%+ "Jamie-ready" with minimal editing required.
