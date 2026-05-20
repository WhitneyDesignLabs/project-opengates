import sys, time, serial

port = sys.argv[1] if len(sys.argv) > 1 else "COM16"
baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200
# Any further args are commands to send (with appended \r\n), after a short settle.
to_send = sys.argv[3:]

sys.stdout.reconfigure(encoding="utf-8", errors="replace", line_buffering=True)

print(f"[capture] opening {port} @ {baud} (no DTR/RTS toggle)", flush=True)
try:
    ser = serial.Serial()
    ser.port = port
    ser.baudrate = baud
    ser.timeout = 0.2
    ser.dtr = False
    ser.rts = False
    ser.open()
except Exception as e:
    print(f"[capture] open failed: {e}", flush=True)
    sys.exit(1)

print("[capture] open ok, reading...", flush=True)

if to_send:
    time.sleep(0.4)
    for cmd in to_send:
        line = (cmd + "\r\n").encode("utf-8")
        ser.write(line)
        ser.flush()
        ts = time.strftime("%H:%M:%S")
        print(f"{ts} | [capture] sent: {cmd!r}", flush=True)
        time.sleep(0.2)

buf = bytearray()
try:
    while True:
        data = ser.read(4096)
        if data:
            buf.extend(data)
            while b"\n" in buf:
                line, _, rest = buf.partition(b"\n")
                buf = bytearray(rest)
                try:
                    s = line.decode("utf-8", errors="replace").rstrip("\r")
                except Exception:
                    s = repr(bytes(line))
                ts = time.strftime("%H:%M:%S")
                print(f"{ts} | {s}", flush=True)
except KeyboardInterrupt:
    pass
finally:
    if buf:
        ts = time.strftime("%H:%M:%S")
        print(f"{ts} | (partial) {buf.decode('utf-8', errors='replace')}", flush=True)
    ser.close()
    print("[capture] closed", flush=True)
