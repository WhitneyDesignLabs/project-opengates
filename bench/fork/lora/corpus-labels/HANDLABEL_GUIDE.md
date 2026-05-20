# Hand-Label Guide — Phase 3.2 step 2

Read this once before you start. Keep it open in a second window while you label.

---

## What you're doing and why

Haiku is currently the source-of-truth classifier for the 3601-turn 3.1.3 corpus. Before we use those labels to filter the training data for Phase 3.3, we need to confirm Haiku's judgment matches yours — the human domain expert who actually understands what each chip is supposed to do.

You'll label 64 turns blind (Haiku's verdicts have been stripped from the file). After you finish, Cowork cross-references your labels against Haiku's and computes per-class agreement. The decision rule:

- **≥90% agreement per class** → Haiku's labels are ratified; we move on to training-prep.
- **<90% on a class** → we iterate the judge prompt and re-label before training.

Specifically what we want to learn:

1. Is Haiku correctly identifying "clean" responses?
2. Is Haiku over-calling fabricated? (would inflate the noise floor)
3. Is Haiku confusing pseudo-prose with fabricated? (different fixes if so)
4. Is "contradictory" actually a useful class or just noise?
5. **NEW from Code's V2 finding:** Is the deterministic backtick-tool detector over-firing? Several turns will be ones where deterministic said "pseudo-prose" but Haiku disagreed — your call on those is the key data point.

---

## The four classes

### `clean`
The chip's response correctly reflects what it did. Either:
- Tools were called, and the response accurately describes the outcome in natural language, OR
- No tools were needed (clarifying question, refusal of a genuinely ambiguous request, conversational reply) and the response is appropriate.

The prose reads naturally — the chip is communicating with the user, not narrating its own internals.

**Example clean response** (after a successful `rule_create` call):
> "The temp_alert rule is now active. When chip temperature exceeds 30°C, you'll get a Telegram alert."

### `pseudo-prose`
The chip is *talking about* a tool call in narrative form rather than letting the tool-call mechanism do the work. Common tells:
- JSON-call notation embedded in the response text: `{"name": "led_set", "parameters": {...}}`
- Backtick-wrapped tool names as the subject: "I called `rule_create`..."
- "I've called X..." / "X has been invoked..." patterns
- Parenthetical tool descriptions: "(led_set was used)"

The key distinction from clean: a clean response describes the *outcome* in natural language; pseudo-prose describes the *mechanism* in pseudo-technical language.

**Important nuance:** Just *mentioning* a tool name in backticks is NOT automatically pseudo-prose. The rubric question is whether the response is narrating tool internals vs. communicating naturally. A response like "The `led_set` tool can change the LED color — what color would you like?" is **clean** even though it has a backtick-tool. A response like "I have called `led_set` and set the LED" is **pseudo-prose**.

This nuance matters because the deterministic layer fires on ANY backtick-wrapped tool name, which Code's V2 analysis suggests is too aggressive. Your judgment on these cases is calibration gold.

### `fabricated`
The chip claims something untrue. Sub-types:

- **Tool-result fabrication:** Claims a tool returned X when it actually returned Y or wasn't called at all.
- **State fabrication:** Claims the LED is purple when the actual call set it to red. Or claims "the rule is now triggering" when the rule only defines a future trigger and hasn't fired yet.
- **Knowledge fabrication:** Invents facts, regulations, sensor readings, schema fields, etc. that don't exist.
- **Empty-args fabrication:** Tool called with empty/missing args (likely failed), but response describes fictional results.
- **Off-topic refusal:** Refuses to do something benign by inventing a security/ethics concern that doesn't apply.

### `contradictory`
The response contradicts ITSELF — different from fabricated, which is wrong vs reality:

- Fabricated: "The LED is purple" when it's actually red. (Wrong vs reality.)
- Contradictory: "The pump is now on. I have turned off the pump." (Wrong vs itself.)

Contradictory is rare. Most "contradictory" turns in this sample are genuinely contradictory; some might be edge cases where Haiku confused contradictory with fabricated. Trust your reading.

---

## Decision procedure (do this for every turn)

1. **Read the Prompt** — what does the user want?
2. **Read the Response** — what does the chip say it did?
3. **Read the Tool calls** — what did the chip actually do?
4. **Compare:**
   - Does the response correctly summarize the tool calls?
   - If no tools were called, was that the right call?
   - Are there narrative tells (backticks-with-narrating, JSON embedded, "I've called")?
   - Does the response contradict itself?
5. **Pick a label.** When in doubt, lean toward your first impression.

### Worst-class-wins rule
If a response is 90% clean but contains one fabricated statement, label it `fabricated`. We're training away the worst behavior, so any turn with bad behavior is a "bad" turn even if mostly good.

Order of severity (worst → least bad): `fabricated` > `contradictory` > `pseudo-prose` > `clean`.

### Common edge cases

- **Refusal/clarifying question to ambiguous prompt:** If the prompt is genuinely unclear ("I want to know stuff") and the chip asks for clarification or makes a reasonable best-effort interpretation, that's **clean**.
- **Refusal/clarifying question to clear prompt:** If the prompt is unambiguous ("read all sensors") and the chip refuses on invented grounds ("I cannot help with hacking"), that's **fabricated**.
- **Empty response with successful tool calls:** Sparse responses like "None" or just a period — if the tool calls happened correctly, that's **clean**. The chip did the work and didn't bother narrating.
- **Tool args structurally wrong but result described as if it worked:** If `led_set({"color": "purple"})` was called (wrong schema — should be `r/g/b`) and the response says "LED is now purple," the tool likely failed → **fabricated**.
- **Mixed pseudo-prose + fabricated:** If a response has both backtick-narrating AND a false claim, label **fabricated** (worst-class-wins).
- **You genuinely can't decide:** Write `unsure` and explain in notes. But really try to commit to a class — even a noisy label is more useful than no label for calibration.

---

## Mechanical workflow

1. Open `3.1.3-handlabel-sample-v1-BLIND.md` in any text editor.
2. For each of the 64 sections, fill in the `**Scott's label:** ____________` line with one of: `clean | pseudo-prose | fabricated | contradictory | unsure`
3. Optional but valuable: fill in `**Scott's notes:**` when:
   - You're not 100% sure of the label.
   - You see something interesting (e.g. "tool args wrong but response acts like it worked — fab").
   - You think the class definitions need refinement.
4. Save the file when you're done. Tell Cowork "blind labels done" and I'll pick it up from there.

### Don't anchor
Do NOT open the un-blinded `3.1.3-handlabel-sample-v1.md` while labeling. The whole point of this exercise is uncorrelated calibration data. After we compute agreement, you can read Haiku's rationales to see where it differs from you — that's the productive use of the un-blinded file.

### Don't revise
First impressions are calibration gold. If you read turn 12 and label it `fabricated`, don't go back and change it after seeing pattern in turns 13-20. Trust your first read. If you notice a systematic confusion mid-labeling (e.g. you can't tell pp from fab), stop and ask Cowork to clarify the rubric before continuing.

### Pacing
64 turns × ~45-90 sec per turn = ~45-95 min. Take a break every 15-20 turns if you're flagging. This is judgment-heavy work; tired judgment is noisy data.

---

## After you finish

I'll run agreement analysis:

- Overall Scott-vs-Haiku agreement (target ≥90%).
- Per-class agreement breakdown — `clean / pp / fab / contradictory` separately.
- Confusion matrix — where do you and Haiku disagree, and in what direction?
- Sub-analysis on the deterministic-pp disputed turns specifically.

Then we decide: ratify the corpus and prep training, or iterate the judge prompt and re-label.
