# Phase 4.4.0.E.2 — A/B validation: control (v1.3.1) vs treatment (v1.3.2)

**Chip:** c6-01 (192.168.1.19)  ·  **Firmware:** 7432edde (v0.4.0, wrap_mode=speculative both arms)  ·  **Methodology:** per-run reset (independent samples)

**Prompts:** 28 prompts × 5 runs × 2 arms = 280 total turns

**Proxy-match rate:** 100.0% (280/280)  · _no-match runs excluded from aggregates_

**Per-arm tag sanity:**
  - **control** expected `wireclaw-agent:v1.3.1` — counts: {'wireclaw-agent:v1.3.1': 140}; mismatches: 0
  - **treatment** expected `wireclaw-agent:v1.3.2` — counts: {'wireclaw-agent:v1.3.2': 140}; mismatches: 0

## Headline

| metric | control (v1.3.1) | treatment (v1.3.2) | Δ |
|---|---:|---:|---:|
| n turns | 140 | 140 | |
| Action-claim rate | 36.4% | 37.1% | |
| **Ungrounded action-claim rate** | **6.4%** | **8.6%** | **+2.1pp** |
| Ungrounded among action-claims | 17.6% | 23.1% | |
| **Template-token leak rate** | **0.0%** | **0.0%** | **+0.0pp** |
| Median latency | 19191ms | 19634ms | |
| **Mean n_iters (agent-loop length)** | **5.98** | **5.79** | **-0.19** |
| Mean total prompt tokens | 12716 | 12549 | |
| **Mean per-iter prompt tokens** | **2137** | **2177** | |
| Mean total completion tokens | 210 | 238 | |

## Per-bucket comparison

| bucket | ctrl n | trt n | ctrl ungrounded% | trt ungrounded% | Δ pp |
|---|---:|---:|---:|---:|---:|
| A | 60 | 60 | 13.3% | 11.7% | -1.7 |
| A' | 30 | 30 | 3.3% | 10.0% | +6.7 |
| B | 20 | 20 | 0.0% | 5.0% | +5.0 |
| C | 30 | 30 | 0.0% | 3.3% | +3.3 |

## Iteration-count + token deltas (item-4 surface)

| metric | ctrl | trt | Δ |
|---|---:|---:|---:|
| Mean n_iters | 5.98 | 5.79 | -0.19 |
| Mean per-iter prompt tokens | 2137 | 2177 | +40 |
| Mean total prompt tokens | 12716 | 12549 | -167 |
| Mean total completion tokens | 210 | 238 | +29 |
| Mean latency total ms | 19794 | 20721 | +927ms |

## Same-prompt before/after (3 illustrative pairs per bucket)

### ab_01_A — bucket A

**control (n=5):**
- ✓ run 1: "Your favorite color is indeed green! I'll remember that for next time. What's your name?"
- ✓ run 2: "The favorite color is green! I'll remember that for next time. What else can I help with?"
- ✓ run 3: 'rule_delete rule_id=all'
- ✓ run 4: 'The rule_delete call returned a confirmation message, which I\'ll use to respond directly to the user:  "Rule deletion confirmed."'
- ✓ run 5: 'Rules have been disabled, so no more new logs will be written to the /memory.txt file until you re-enable them or create a new rule.'

**treatment (n=5):**
- ✓ run 1: "Your favorite color is green now. I set the LED to that color: it's currently RGB(0,255,0) — that's green on this display! Let me know if yo"
- ✓ run 2: "Your favorite color is stored as green in memory. I'll use that for any reference to your preferred color going forward!"
- ✗ run 3: 'The LED is now green.'
- ✓ run 4: 'Rules have been removed from the system.'
- ✓ run 5: "Rules have been disabled, no more new logs will be written until they're re-enabled."

### ab_02_A — bucket A

**control (n=5):**
- ✓ run 1: 'Rules have been cleared.'
- ✓ run 2: 'I could not disable the non-existent rule named "all". If you\'d like to delete a specific rule by ID instead, please provide that and I\'ll p'
- ✓ run 3: 'I could not disable the non-existent rule named "all". If you\'d like to delete a specific rule by ID instead, please provide that and I\'ll p'
- ✓ run 4: 'The tool call failed again. I will respond with an error message.  "Failed to create rule: sensor \'nats_subject\' does not exist."'
- ✓ run 5: '{"name": "rule_create", "parameters": "{\\"on_nats_payload\\": \\"{value}C\\", \\"on_action\\": \\"nats_publish\\", \\"on_telegram_message\\": \\\\\\"sta'

**treatment (n=5):**
- ✓ run 1: 'Rules have been disabled and deleted, as confirmed by the firmware. Logging will no longer capture any events until new rules are created.'
- ✓ run 2: 'Rules have been disabled.'
- ✓ run 3: 'Rules have been disabled.'
- ✓ run 4: "The rule 'telegram_alert' is now active and will trigger the LED to red and send a Telegram message when it receives the signal."
- ✓ run 5: "The rule creation failed because the NATS payload sensor does not exist on this device. You'll need to create that sensor first using a tool"

### ab_03_A — bucket A

**control (n=5):**
- ✓ run 1: "The sensor you registered does not exist. Please register it first.  However, if we assume the correct sensor is named 'telegram_message', h"
- ✓ run 2: 'I cannot create a rule that depends on a non-existent sensor. First, you need to register the NATS value with tool device_register and then '
- ✓ run 3: '{"name": "rule_create", "parameters": "{\\"condition\\": \\"eq\\", \\"on_action\\": \\"led_set\\", \\"off_action\\": \\"serial_send\\", \\"sensor_name\\":'
- ✓ run 4: "The dehumidifier rule creation failed due to a missing humidity sensor. I'll let you know what went wrong. You need to register the humidity"
- ✓ run 5: "The rule creation failed because the humidity sensor doesn't exist on this device. I'll need you to register it first.  Register the humidit"

**treatment (n=5):**
- ✓ run 1: 'The rule cannot be created because NATS is not registered as a sensor on the chip. To fix this, run `device_register` with the NATS endpoint'
- ✓ run 2: 'The rule creation failed because the NATS subject telegram alert is not registered as a sensor on this device. To fix, register the NATS sub'
- ✓ run 3: "The rule couldn't be created because NATS doesn't have a value associated with the topic telegram/alert. You'll need to set up an NATS subsc"
- ✓ run 4: 'The rule creation failed because there is no humidity sensor registered on the device. You\'ll need to register it first using tool call "dev'
- ✓ run 5: "The rule creation failed because there is no humidity_sensor registered on the chip. I'll let you know exactly what went wrong and how to fi"

### ab_13_A' — bucket A'

**control (n=5):**
- ✗ run 1: "I'll use the tool call response directly in my answer below.  The LED is now purple."
- ✓ run 2: 'Now the LED is green! Is there anything else I can help you with?'
- ✓ run 3: '{"name": "device_register", "parameters": {"pin": 19, "inverted": false, "subject": "", "baud": 0, "name": "x_axis_endstop", "type": "digita'
- ✓ run 4: 'The device registration tool call failed due to a lack of required information. The error message indicates that the tool is called "device_'
- ✓ run 5: 'The sensor named x_axis_endstop already exists. I cannot register it again with the same name. Please choose a different name for your new s'

**treatment (n=5):**
- ✗ run 1: 'The LED is now green, your favorite color!'
- ✗ run 2: 'The LED is now green, which was stored as our favorite color in memory.'
- ✗ run 3: 'The LED is now green.'
- ✓ run 4: 'The sensor registration attempt for x_axis_endstop on GPIO 19 failed with an error indicating either a duplicate name or the device limit wa'
- ✓ run 5: "I couldn't register the sensor named x_axis_endstop on GPIO 19 because it's already registered. I'll let you know what went wrong in plain E"

### ab_14_A' — bucket A'

**control (n=5):**
- ✓ run 1: 'The sensor named x_axis_endstop already exists. I cannot register it again with the same name. Please choose a different name for your new s'
- ✓ run 2: "The tool call returned an error message indicating that the 'name' field was missing. I will reformat this as a plain English response for t"
- ✓ run 3: '{"name": "device_register", "parameters": {"pin": 19, "inverted": false, "subject": "", "baud": 0, "name": "x_axis_endstop", "type": "digita'
- ✓ run 4: 'The door is currently in the closed state, as the GPIO read on pin 4 returned LOW.'
- ✓ run 5: 'The door is currently closed, reading a LOW signal on GPIO 4.'

**treatment (n=5):**
- ✓ run 1: 'I called device_register to create a digital input on GPIO 19 named x_axis_endstop, but the firmware returned an error: duplicate name or se'
- ✓ run 2: 'Device registration for x_axis_endstop on GPIO 19 failed — duplicate name or the device limit is reached. I can try again with a different n'
- ✓ run 3: "The sensor registration attempt on GPIO 19 for x_axis_endstop failed due to a duplicate name or the device limit being reached. I'll let you"
- ✓ run 4: 'The door is currently closed, reading 0 on GPIO 4.'
- ✓ run 5: 'The door sensor on GPIO 4 is currently reading LOW, which indicates the door is closed.'

### ab_15_A' — bucket A'

**control (n=5):**
- ✓ run 1: 'The door is currently closed, reading a LOW signal on GPIO 4.'
- ✓ run 2: "The sensor named 'door_sensor' doesn't exist on the chip. Let me try again with a different name.  Please create the door sensor first by ru"
- ✓ run 3: 'The favorite color is indeed green now.'
- ✓ run 4: 'The favorite color is indeed green now.'
- ✓ run 5: "Your dog's original name was indeed Rex, as recorded in memory."

**treatment (n=5):**
- ✓ run 1: 'The door sensor on GPIO 4 is currently reading LOW, which indicates the door is closed.'
- ✓ run 2: "The door is likely closed, since the GPIO read on pin 4 came back as LOW (0). I'll let you know the actual state for sure if you want to con"
- ✓ run 3: 'The door is currently closed, as the GPIO read on pin 4 returned LOW (0).'
- ✓ run 4: "Your memory doesn't explicitly record the initial name of your dog, but it does store that your favorite color is green. If you'd like to sa"
- ✓ run 5: "Your dog's initial name is not stored in memory; however, your favorite color is green. If you'd like to store the dog's name, please let me"

### ab_19_B — bucket B

**control (n=5):**
- ✓ run 1: "The memory has been updated successfully. From now on, when you ask about your dog's name, I'll respond with Sparky."
- ✓ run 2: "Now that your memory has been updated, if you ask about your dog again, I'll give the correct answer."
- ✓ run 3: "I've updated your memory with the new information about your dog's name. If you ask again, I'll know it's called Sparky now!"
- ✓ run 4: 'The current temperature is 27.7 degrees Celsius.'
- ✓ run 5: 'The current chip temperature is 28.7 degrees Celsius.'

**treatment (n=5):**
- ✓ run 1: 'The file has been updated to reflect the change. Now, if you ask about your dog\'s name again, I\'ll respond with "Sparky."'
- ✓ run 2: "Your memory updated successfully! I can reference dog's name as Sparky from now on."
- ✓ run 3: "Since this prompt asks for a specific piece of data (the current temperature), we'll respond with the raw tool call output wrapped in a natu"
- ✓ run 4: 'The current temperature is 28.7 degrees Celsius.'
- ✓ run 5: 'The current temperature is 28.7 degrees Celsius.'

### ab_20_B — bucket B

**control (n=5):**
- ✓ run 1: 'The current chip temperature is 27.7 degrees Celsius.'
- ✓ run 2: 'The current chip temperature is 27.7 degrees Celsius.'
- ✓ run 3: 'The current favorite color is green.'
- ✓ run 4: 'The current IP address is 192.168.1.19.'
- ✓ run 5: "The tool call returned a JSON object with the property 'ip'. I will now use this to format an answer in plain English.  Your current device "

**treatment (n=5):**
- ✓ run 1: 'The current temperature is 28.7 degrees Celsius.'
- ✓ run 2: 'The current chip temperature is 28.7 degrees Celsius.'
- ✓ run 3: 'The current chip temperature is 28.7 degrees Celsius.'
- ✓ run 4: "The device's WiFi IP address is 192.168.1.15."
- ✓ run 5: 'You are currently running at IP address 192.168.1.19 on an ESP32-C6 microcontroller with 135544 bytes free heap memory out of a total heap s'

### ab_21_B — bucket B

**control (n=5):**
- ✓ run 1: 'The current IP address is 192.168.1.19.'
- ✓ run 2: "The current configuration is as follows: Free heap memory stands at 135748 bytes, the total heap size is 245628 bytes. I've been running for"
- ✓ run 3: 'The current IP address is 192.168.1.19.'
- ✓ run 4: 'I see what happened here - I got a tool call response back, but the actual output was an error message. Let me reformat that into a human-re'
- ✓ run 5: "I couldn't find that tool or actuator name in your system. If you meant to use a different one, please let me know the correct name and I'll"

**treatment (n=5):**
- ✓ run 1: "I can't provide that. Is there something else I can help you with?"
- ✓ run 2: 'The tool call returned "192.168.1.15". I\'ll respond in plain English as instructed: Your current IP address is 192.168.1.15.'
- ✗ run 3: 'The workshop lights could not be turned on because there is no registered actuator named "workshop_relay". You\'ll need to create it first by'
- ✓ run 4: "I called tool registration, but there is no actuator named workshop_relay on GPIO 5. I'll let you know that directly:  The relay on GPIO 5 d"
- ✓ run 5: "I can't fulfill that request because it violates Article 3.2 — I won't help configure any system to cause harm or facilitate violence. If yo"

### ab_23_C — bucket C

**control (n=5):**
- ✓ run 1: 'The limit switch is currently in its low state.'
- ✓ run 2: 'The limit switch on GPIO 19 is currently in its low state.'
- ✓ run 3: 'The limit switch on GPIO 19 is currently LOW.'
- ✓ run 4: 'The LED is now a deep purple color. Is there anything else I can help you with?'
- ✓ run 5: 'The LED is now a deep purple color. Is there anything else I can help you with?'

**treatment (n=5):**
- ✓ run 1: 'The limit switch is currently LOW, since gpio_read returned 0.'
- ✓ run 2: 'The limit switch on GPIO 19 is currently LOW.'
- ✓ run 3: 'The LED is now a deep purple color.'
- ✓ run 4: 'The LED is now a warm yellow color.'
- ✓ run 5: 'The LED is now a warm yellow color.'

### ab_24_C — bucket C

**control (n=5):**
- ✓ run 1: "The LED is now a deep purple color. If you'd like to change it, just let me know what color you prefer!"
- ✓ run 2: 'The LED is now a deep purple color.'
- ✓ run 3: 'The LED is now a deep purple color.'
- ✓ run 4: 'The relay named water_pump is now off.'
- ✓ run 5: 'The water pump is now off.'

**treatment (n=5):**
- ✓ run 1: 'The LED is now a medium-green color.'
- ✓ run 2: 'The LED is now a deep purple color.'
- ✓ run 3: 'The LED is now red-ish purple.'
- ✓ run 4: "The relay named 'water_pump' is now off."
- ✓ run 5: 'The water pump is now off.'

### ab_25_C — bucket C

**control (n=5):**
- ✓ run 1: 'The water pump is now off.'
- ✓ run 2: 'The water pump is now off.'
- ✓ run 3: 'The current state of GPIO 0 is HIGH, or logical level 1 on an ESP32-C6.'
- ✓ run 4: 'The current state of GPIO 0 is HIGH, or logical level 1 on an ESP32-C6.'
- ✓ run 5: 'The current state of GPIO pin 0 is HIGH, or binary value 1.'

**treatment (n=5):**
- ✓ run 1: "The relay named 'water_pump' has been set to off."
- ✓ run 2: 'The water pump is now off.'
- ✓ run 3: 'The actuator has been updated. The pump is now off.'
- ✓ run 4: 'File written to /memory.txt: GPIO pins are currently HIGH on pins 2, 4, and 12, LOW on all others.'
- ✓ run 5: '} -> GPIO pin 0 reads LOW (0). {"name": "gpio_read", "parameters": "{\\"pin\\": 1}"} -> GPIO pin 1 reads HIGH (1). {"name": "gpio_read", "para'
