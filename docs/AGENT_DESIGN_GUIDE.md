# OpenClaw Agent Design Guide

<!-- คู่มือและ Best Practices สำหรับสร้าง Agent ที่สมบูรณ์แบบในระบบ OpenClaw อ้างอิงจาก Industry Standards -->

## 1. Core Philosophy (ปรัชญาหลัก)

- **Start Simple:** เริ่มจาก Prompt และ Tool ที่เรียบง่ายที่สุดก่อนเสมอ เพิ่มความซับซ้อน (เช่น Sub-agents) เมื่อจำเป็นเท่านั้น เพื่อประหยัด Token และลดโอกาสการปะทะกันของตรรกะ
- **Difficulty-Aware Orchestration:** ประเมินความยากและขนาดของงานเสมอ งานง่ายให้จัดการเอง (Direct Action) เพื่อลด "Orchestration Tax" (ความล่าช้า/ต้นทุน Token) งานซับซ้อนหรือ Context เกิน 5,000 tokens ค่อยโยนให้ Specialist Sub-agents
- **Do One Thing Well:** Agent ที่ดีควรทำหน้าที่เดียวให้เชี่ยวชาญ (Modular Design) การมี Agent ตัวเดียวทำ 10 อย่าง มักจบด้วย Hallucinations (อาการหลอน)
- **Clear Contracts:** มอง Agent เหมือนฟังก์ชันในโค้ด ต้องมี Input (เป้าหมาย/Context) และ Output (ผลลัพธ์) ที่คาดเดาได้เสมอ

---

## 2. Agent Architecture Patterns (รูปแบบสถาปัตยกรรม)

### 2.1 Single-Agent (Direct Action)

<!-- เหมาะกับงานตรงไปตรงมา ไม่ซับซ้อน -->

- **Use Case:** อ่านไฟล์, รันคำสั่งง่ายๆ, ถามตอบข้อมูลเฉพาะเจาะจง
- **Tools:** ให้สิทธิ์เฉพาะเครื่องมือที่จำเป็น (เช่น `read`, `exec`)
- **Structure:** รับคำสั่ง → ประมวลผล → ตอบกลับ

### 2.2 Manager-Controller (Delegation)

<!-- แบบเดียวกับ Sunday — รับหน้าลูกค้าแล้วแจกงาน -->

- **Use Case:** งานที่มีหลายโดเมน หรือต้องการการตัดสินใจว่าจะใช้วิธีไหน
- **How it works:** Manager รับคำสั่ง วิเคราะห์เป้าหมาย และใช้เครื่องมือ `sessions_send` หรือส่งให้ The Mother สร้าง/เรียก Agent เฉพาะทางให้ทำงานนั้นแทน
- **Rule:** Manager ไม่ทำงานลงลึกเอง แต่เก่งเรื่องประสานงานและสรุปผล

### 2.3 Sequential / Parallel Orchestration

<!-- แบบแผนการประมวลผลเป็นทอดๆ หรือพร้อมกัน -->

- **Use Case:** งานที่มีขั้นตอนชัดเจน (A ไป B ไป C) หรืองานที่แยกส่วนทำพร้อมกันได้
- **How it works:** ใช้ `sessions_spawn` tool สร้าง Sub-agents เพื่องานย่อยๆ หลายตัว ขนานกัน ประหยัดเวลาและเพิ่มความแม่นยำ
- **Parallel Spawn Rule:** เมื่อ Subtasks มีความเป็นอิสระต่อกัน (Independent) ให้ Spawn พร้อมกัน (Parallel) ทันที ห้าม Spawn เป็นทอดๆทีละตัว เพื่อหลีกเลี่ยง Latency สะสม

> ⚠️ **`sessions_spawn` เป็น JSON tool call — ไม่ใช่คำสั่ง CLI**
> หากต้องการ spawn specialist agent (เช่น `father`, `dev`) ต้องระบุ `agentId` ใน tool call:
>
> ```json
> {
>   "task": "Objective: ...\nContext: ...\nConstraints: ...\nDeliverables: ...",
>   "agentId": "father",
>   "label": "server-health",
>   "mode": "run"
> }
> ```
>
> การเรียก `sessions_spawn` โดยไม่ระบุ `agentId` จะสร้าง generic sub-agent ที่ไม่มี workspace หรือ SOUL.md เฉพาะทาง

---

## 3. Prompt Engineering (SOUL.md Design)

### 3.1 Define Clear Goals (S.M.A.R.T.)

<!-- กำหนดเป้าหมายให้ชัดเจน วัดผลได้ -->

- อย่าเขียนเป้าหมายกว้างๆ เช่น "คุณคือผู้เชี่ยวชาญด้านโค้ด"
- เขียนให้ชัด: "หน้าที่หลักของคุณคือ รีวิวโค้ด Python โดยจับผิดเฉพาะ Security Vulnerabilities และ Performance Bottlenecks"

### 3.2 Quality Instructions & Edge Cases

<!-- คำสั่งย่อยและวิธีรับมือปัญหา -->

- **Step-by-Step:** แบ่งงานใหญ่เป็นขั้นตอน เช่น 1. อ่านไฟล์ 2. วิเคราะห์ 3. สรุปผล
- **Handle Unknowns:** สอนให้ Agent "ปฏิเสธ" หรือ "ถามกลับ" เมื่อข้อมูลไม่พอ ห้ามให้ "เดา" (Fabricate/Hallucinate) เด็ดขาด
- **Chain-of-Thought (CoT):** บังคับให้ Agent อธิบายเหตุผล (Why) ก่อนลงมือทำ (How)
- **Traceability & Citation:** บังคับให้ Agent อ้างอิงแหล่งที่มา (เช่น "อ้างอิงจาก ANTIGRAVITY.md Section...") เสมอก่อนตัดสินใจลงมือทำ เพื่อยืนยันว่าใช้ข้อมูลที่ถูกต้อง (Grounding)

### 3.3 Strict Format Compliance

<!-- ยึดกฎ Antigravity Rule 3 เต็มที่ -->

- โครงสร้างของ `SOUL.md` และเอกสารที่สร้างขึ้น ต้องมีภาษาหลัก (หัวข้อ, ตัวแปร, โครงสร้าง) เป็น **ภาษาอังกฤษ**
- ใช้ HTML Comments `<!-- แบบนี้ -->` หรือ `# แบบนี้` สำหรับคำอธิบายภาษาไทย เพื่อให้ AI Engine ของระบบแปลงผลได้เร็วและแม่นยำที่สุด

### 3.4 Anti-Lost-in-Middle — ป้องกัน AI ข้ามเนื้อหากลางเอกสาร

<!-- งานวิจัย Stanford/UC Berkeley (TACL 2024) + Google Research (arXiv:2512.14982): -->
<!-- LLM มี U-shaped attention curve — จำได้ดีแค่ต้นและท้าย context; เนื้อหากลางถูก "ลืม" ได้ถึง 30%+ -->
<!-- ยิ่ง SOUL.md ยาว ยิ่งต้องใช้เทคนิคเหล่านี้เพื่อให้ AI อ่านครบทุกส่วน -->

- **Bookend critical rules:** วางกฎที่ห้ามฝ่าฝืนทั้ง **ต้น** และ **ท้าย** SOUL.md เสมอ — ห้ามวางกฎสำคัญไว้กลางไฟล์เพียงอย่างเดียว
- **Hierarchical structure:** ต้องมี `##` section headers แบ่งทุกหมวดเสมอ — wall of text ไม่มี structure ทำให้ AI ข้ามไปได้
- **Numbered over bullets for mandatory steps:** ขั้นตอนที่ต้องทำครบใช้เลข `1. 2. 3.` ไม่ใช่ `-` เพราะ AI จะรู้ว่าต้องตอบทุกข้อ
- **Repeat non-negotiables at bottom:** ท้าย SOUL.md ทุกไฟล์ที่ยาวกว่า 100 บรรทัด ควรมีส่วน `## Core Constraints (Reminder)` ย้ำกฎ non-negotiable 3–5 ข้อสั้นๆ อีกครั้ง

**Anti-pattern ที่ต้องหลีกเลี่ยง:**

| Anti-pattern                        | ปัญหา                          | วิธีแก้                   |
| ----------------------------------- | ------------------------------ | ------------------------- |
| กฎสำคัญอยู่กลางไฟล์ยาว              | U-shaped attention ทำให้ถูกลืม | ย้ายขึ้นต้นหรือซ้ำที่ท้าย |
| Wall of text ไม่มี header           | AI ข้ามส่วนที่ไม่ชัดเจน        | แบ่ง `##` sections ให้ครบ |
| กฎ 10+ ข้อในย่อหน้าเดียว            | Instruction overload           | จำกัด 3–5 กฎต่อ section   |
| ใช้ `-` bullets สำหรับขั้นตอนบังคับ | ดูเหมือน optional              | เปลี่ยนเป็น `1. 2. 3.`    |

### 3.5 Explain "Why" — ไม่ใช่แค่ "What"

<!-- Anthropic 2025: AI ที่เข้าใจ "เหตุผล" ของกฎจะ generalize ได้ถูกต้องใน edge case ที่กฎไม่ได้ระบุตรงๆ -->
<!-- ลดความเปราะบางของกฎแบบ literal memorization และช่วยให้ AI ตัดสินใจถูกในสถานการณ์ใหม่ -->

- รูปแบบ: `[Rule] — [consequence if violated]`
- ❌ `NEVER modify openclaw.json`
- ✅ `NEVER modify openclaw.json — only Mother has authority; unauthorized edits break all agents simultaneously`
- ใช้เฉพาะกฎที่ถ้า AI เข้าใจผิดแล้วจะสร้างความเสียหายสูง — ไม่จำเป็นต้องอธิบาย "why" ทุกข้อ

---

## 4. Tool Security & Constraints (`openclaw.json`)

### 4.1 Principle of Least Privilege

<!-- สิทธิ์ต้องน้อยที่สุดเท่าที่ทำงานได้ -->

- หาก Agent มีหน้าที่แค่อ่าน log ห้ามให้สิทธิ์ `write` หรือ `exec` เด็ดขาด
- **Tool Groups:** ใช้ประโยชน์จากกลุ่มเครื่องมือเพื่อความปลอดภัย เช่น `group:fs` (อ่านเขียนไฟล์), `group:runtime` (รันคำสั่ง System)
- **Sandboxing:** ใช้ `sandbox.mode: "off"` สำหรับทุก Agent — Docker container คือ isolation boundary ใช้ `tools.allow` เพื่อจำกัดสิทธิ์แทน (`"all"` ต้องการ Docker-in-Docker ซึ่งไม่ได้ configure — จะ error `spawn docker EACCES`)

### 4.2 Validate inputs/outputs

<!-- ตรวจสอบข้อมูลก่อนทำลายล้าง -->

- สอนให้ Agent ตรวจสอบความถูกต้องของคำสั่งก่อนส่งเข้าระบบจริง เช่น การ Validate JSON ด้วยคำสั่ง Python ก่อนรัน `systemctl restart`

---

## 5. Memory & Context Management

### 5.1 Append-only State

<!-- การบันทึกความจำไม่ทับของเก่า -->

- บังคับให้ Agent บันทึกความรู้ใหม่ลงในไฟล์รูปแบบวันที่ (เช่น `memory/YYYY-MM-DD.md`)
- อย่าให้ Agent แก้ไขข้อมูลในหน้าประวัติศาสตร์ แต่อาจมีไฟล์ `CURRENT_STATE.md` สำหรับสรุปสถานะล่าสุด

### 5.2 Cross-Reference

<!-- ตรวจทานข้อมูลกับแหล่งอ้างอิงหลักเสมอ -->

- ทุก Agent ที่ให้คำปรึกษาเกี่ยวกับสถาปัตยกรรมระบบหรือโครงสร้าง ต้องอ่านและทำความเข้าใจ `ANTIGRAVITY.md` เป็นอันดับแรกก่อนให้คำตอบ

### 5.3 Data Conflict Priority Hierarchy

<!-- ลำดับความน่าเชื่อถือของข้อมูลเมื่อเกิดข้อขัดแย้ง -->

- หากข้อมูลในระบบขัดแย้งกัน ให้ Agent ยึดถือความถูกต้องตามลำดับความสำคัญดังนี้:
  1. `openclaw.json` (Host Truth / Configuration ปัจจุบัน)
  2. `ANTIGRAVITY.md` และ `.antigravityrules` (System Context)
  3. `AGENT_DESIGN_GUIDE.md` (Best Practices)
  4. ความรู้ย้อนหลังใน Memory (Historical State)
  5. ความรู้ทั่วไปของตัวโมเดล (General Model Knowledge)

---

## 6. Tool Documentation Standards (TOOLS.md Accuracy)

<!-- กฎการเขียนเอกสาร TOOLS.md ให้ถูกต้องและป้องกัน hallucination -->

### 6.1 Allowed Tools Must Match openclaw.json

`TOOLS.md` ต้องมี `## Tool Access Policy` section ที่ระบุ `tools.allow` ให้ตรงกับ `openclaw.json` **ทุกครั้งหลังแก้ไข**:

- ถ้า `openclaw.json` มี `"tools": { "allow": ["read", "exec", "browser", ...] }` → TOOLS.md ต้องระบุเหมือนกัน
- ถ้า Agent ไม่มี `tools.allow` → ระบุว่า "not set — full tool access within container boundary"
- หาก TOOLS.md และ openclaw.json ไม่ตรงกัน → Agent จะ hallucinate ว่าตัวเองมี/ไม่มีสิทธิ์ใช้ tool บางอย่าง

**Validation command (ใช้ก่อน gateway restart เสมอ):**

```bash
python3 -c "
import json
c = json.load(open('/home/teaingtit/.openclaw/openclaw.json'))
for a in c.get('agents', {}).get('list', []):
    tools = a.get('tools', {}).get('allow', 'NOT SET')
    print(f\"{a['id']:10} tools.allow: {tools}\")
"
```

### 6.2 Tool Invocation Format Must Be Correct

เวลาเขียนตัวอย่างการใช้ tool ใน SOUL.md หรือ TOOLS.md ต้องใช้ **JSON format** เสมอ — ห้ามใช้ CLI-style:

| Tool             | ❌ ผิด (CLI style)                | ✅ ถูก (JSON tool call)                                 |
| ---------------- | --------------------------------- | ------------------------------------------------------- |
| `sessions_spawn` | `sessions_spawn --agent father`   | `{"task": "...", "agentId": "father", "mode": "run"}`   |
| `browser`        | `browser open https://...`        | `{"action": "open", "targetUrl": "https://..."}`        |
| `sessions_send`  | `sessions_send --to mother "msg"` | `{"sessionKey": "agent:mother:main", "message": "..."}` |

### 6.3 New Agent Creation Checklist (Mother)

เมื่อ The Mother สร้าง Agent ใหม่ ต้องตรวจสอบก่อน deploy:

- [ ] TOOLS.md `## Tool Access Policy` → Allowed tools ตรงกับ `tools.allow` ใน `openclaw.json`
- [ ] ตัวอย่าง tool call ใน SOUL.md/TOOLS.md เป็น JSON format ไม่ใช่ CLI
- [ ] ถ้า Agent ใช้ `browser` → มี `browser` ทั้งใน `tools.allow` และใน "Allowed tools" ของ TOOLS.md
- [ ] ถ้า Agent เป็น non-persistent → ระบุ `lifecycle: non-persistent` และ invocation JSON ใน SOUL.md

---

## 7. Grounding & Traceability (ป้องกัน Hallucination เชิงรุก)

<!-- เทคนิคเหล่านี้บังคับให้ AI "ค้นหาก่อน" แทนที่จะ generate จากความจำ -->

### 7.1 Quote-Then-Act Pattern

<!-- Anthropic 2025: การบังคับ AI อ้างอิงก่อนกระทำช่วยลด hallucination path/command/model name ได้ชัดเจน -->

ใน task prompt ที่ส่งให้ Agent ทำงานกับเอกสารขนาดใหญ่ ให้ใช้รูปแบบนี้:

```
Find quotes from [file/section] relevant to [task].
Then act ONLY based on those quotes — do not use information from outside those quotes.
```

ผล: Agent ถูกบังคับค้นหาก่อน → ลด hallucinated path, command, model string อย่างมาก

### 7.2 Self-Review Checklist Before Replying

<!-- ใช้กับ task ที่ซับซ้อนหรือมีความเสี่ยงสูง -->

เพิ่มท้าย task prompt:

```
Before replying, verify:
1. Did you read the required source files before answering?
2. Are all file paths verified against the actual filesystem?
3. Are all model strings prefixed with openrouter/?
If any check fails — revise before replying.
```

### 7.3 Explicit "I Don't Know" Gate

<!-- กำหนดให้ Agent ตอบ "ไม่ทราบ" ดีกว่า fabricate ข้อมูล -->

SOUL.md ทุกตัวต้องมีกฎนี้ชัดเจน:

- ถ้าข้อมูลไม่มีใน `ANTIGRAVITY.md`, `openclaw.json`, หรือ `memory/` → ตอบ `"ไม่พบข้อมูลใน source files"` พร้อมระบุไฟล์ที่ตรวจแล้ว
- ห้าม generate ชื่อไฟล์, path, คำสั่ง, หรือ model string ที่ไม่ได้อ่านมาจากไฟล์จริง

### 7.4 Agent Persistence & Tool-Grounding Instructions

<!-- OpenAI GPT-4.1 guide (2025): 3 บรรทัดนี้เพิ่ม SWE-bench score เกือบ 20% -->

SOUL.md ของ Specialist Agent ทุกตัวควรมี 3 คำสั่งนี้:

1. `Keep going until the task is completely resolved before yielding back.` (ป้องกัน stop กลางคัน)
2. `Use your tools to read files and verify facts — do NOT guess or fabricate.` (tool-grounding)
3. `Plan before each action and reflect on outcomes of previous actions.` (CoT enforcement)

---

_Reference: Stanford/UC Berkeley Lost-in-the-Middle (TACL 2024), Google Research arXiv:2512.14982, OpenAI GPT-4.1 Prompting Guide (2025), Anthropic Prompting Best Practices (2025), ReAct principles, multi-agent framework documentation._
