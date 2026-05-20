"""
Build tools_examples.json from tools_stock.json by augmenting each tool's
description with worked input->output examples. This is the variant that
tests fork patch #2 from the WireClaw audit.

The thesis (from Project Opengates / SAP findings, Feb 2026):
  Small models (8B) learn from examples, not instructions.
  qwen3:8b emitted abbreviated paths like 'gpio.sh led on' from a description
  like "Use this command to turn on the LED" but emitted the full path
  '/home/scott/.openclaw/.../gpio.sh led on' when given an explicit example.
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
stock = json.loads((HERE / "tools_stock.json").read_text())

# Examples are keyed by tool name. Crafted to demonstrate:
#   - Direct value-for-word mapping ("red" -> 255,0,0)
#   - Full-string preservation for path/subject args (Mode B defense)
#   - Common phrasings users actually say
EXAMPLES = {
    "led_set": "Ex: 'set LED red' -> r=255,g=0,b=0. 'LED blue' -> r=0,g=0,b=255. 'turn off LED' -> r=0,g=0,b=0.",
    "gpio_write": "Ex: 'turn on GPIO 10' -> pin=10,value=1. 'pin 4 off' -> pin=4,value=0.",
    "gpio_read": "Ex: 'read GPIO 5' -> pin=5. 'what is pin 2?' -> pin=2.",
    "device_info": "Ex: 'system status' or 'how much memory left?' or 'chip info'.",
    "file_read": "Ex: 'read /memory.txt' -> path='/memory.txt'. 'show notes' -> path='/memory.txt'.",
    "file_write": "Ex: 'remember favorite color is blue' -> path='/memory.txt',content='User favorite color: blue'. ALWAYS preserve user-specified strings verbatim.",
    "nats_publish": "Ex: 'publish hello to topic test.greet' -> subject='test.greet',payload='hello'. ALWAYS use full subject including dots.",
    "temperature_read": "Ex: 'chip temperature?' or 'how hot is the chip?' or 'temp reading'.",
    "device_register": "Ex: 'register pot on GPIO 2 called knob' -> name='knob',type='analog_in',pin=2. 'NATS sensor on home.kitchen.temperature called kitchen' -> name='kitchen',type='nats_value',subject='home.kitchen.temperature'. ALWAYS preserve full subject strings with all dots.",
    "device_list": "Ex: 'list devices' or 'what is registered?' or 'show devices'.",
    "device_remove": "Ex: 'remove knob' -> name='knob'. 'unregister fan' -> name='fan'.",
    "sensor_read": "Ex: 'read knob' -> name='knob'. 'what is the temperature?' -> name='chip_temp'.",
    "actuator_set": "Ex: 'turn on fan' -> name='fan',value=1. 'set led_dim to 128' -> name='led_dim',value=128.",
    "rule_create": "Ex: 'alert when chip_temp > 28' -> rule_name='Temp Alert',sensor_name='chip_temp',condition='gt',threshold=28,on_action='telegram',on_telegram_message='Chip temp: {value} C'. 'every 2 min send temp' -> rule_name='Temp Periodic',sensor_name='chip_temp',condition='always',interval_seconds=120,on_action='telegram',on_telegram_message='Temp: {value} C'. ALWAYS include rule_name. ALWAYS preserve user-specified message templates verbatim.",
    "rule_list": "Ex: 'list rules' or 'what rules exist?' or 'show rules'.",
    "rule_delete": "Ex: 'delete rule 1' -> rule_id='rule_01'. 'delete all rules' -> rule_id='all'.",
    "rule_enable": "Ex: 'disable rule_02' -> rule_id='rule_02',enabled=false. 'enable rule_01' -> rule_id='rule_01',enabled=true.",
    "serial_send": "Ex: 'send GET_TEMP to the arduino' -> text='GET_TEMP'. 'send hello over serial' -> text='hello'.",
    "remote_chat": "Ex: 'ask wireclaw-02 the temperature' -> device='wireclaw-02',message='What is the temperature?'.",
    "chain_create": "Ex: 'when temp > 30: telegram, then LED red after 5s, then LED off after 10s' -> sensor_name='chip_temp',condition='gt',threshold=30,step1_action='telegram',step1_message='Temp: {value}C',step2_action='led_set',step2_delay=5,step2_r=255,step2_g=0,step2_b=0,step3_action='led_set',step3_delay=10,step3_r=0,step3_g=0,step3_b=0.",
}

missing = [t["function"]["name"] for t in stock if t["function"]["name"] not in EXAMPLES]
extra = [k for k in EXAMPLES if k not in [t["function"]["name"] for t in stock]]
assert not missing, f"Missing examples for: {missing}"
assert not extra, f"Examples reference unknown tools: {extra}"

for tool in stock:
    name = tool["function"]["name"]
    orig_desc = tool["function"]["description"]
    tool["function"]["description"] = f"{orig_desc} {EXAMPLES[name]}"

out_path = HERE / "tools_examples.json"
out_path.write_text(json.dumps(stock, indent=2))
print(f"Wrote {out_path} ({out_path.stat().st_size} bytes)")
