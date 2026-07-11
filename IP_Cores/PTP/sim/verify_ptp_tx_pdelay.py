from iss_ptp_tx import build_pdelay_req, build_pdelay_resp, full_frame_with_fcs

def reassemble(fname):
    nibs=[int(x) for x in open(fname).read().split()]
    i=0
    while i<len(nibs) and nibs[i]==5: i+=1
    assert nibs[i]==0xD, "SFD no hallado"
    i+=1
    pn=nibs[i:]
    data=bytearray()
    for k in range(0,len(pn)-1,2):
        data.append((pn[k+1]<<4)|pn[k])
    return data

CLOCK_ID=0x0011223344556677; PORT_NUM=0x0001; SRC_MAC=0x02DECAFBADED

# --- Pdelay_Req ---
ts=[int(x) for x in open("tx_req_ts.txt").read().split()]
req = reassemble("tx_req_stream.txt")
exp_req = full_frame_with_fcs(build_pdelay_req(CLOCK_ID, PORT_NUM, SRC_MAC, 0, ts[0], ts[1]))
print("REQ  rtl:", req.hex())
print("REQ  exp:", exp_req.hex())
if bytes(req)==bytes(exp_req):
    print("=== Pdelay_Req: BIT-IDENTICA — PASS ===")
else:
    for j in range(min(len(req),len(exp_req))):
        if req[j]!=exp_req[j]:
            print(f"REQ difiere byte {j}: {req[j]:#x} vs {exp_req[j]:#x}"); break
    raise SystemExit("REQ FALLO")

# --- Pdelay_Resp --- (seq=1 porque el motor incremento tras el Req)
T2_SEC=7; T2_NS=2500; REQ_PID=0x00AABBCCDDEEFF000002
t3=[int(x) for x in open("tx_resp_t3.txt").read().split()]
T3_SEC,T3_NS=t3[0],t3[1]
residence_ns=(T3_SEC*10**9+T3_NS)-(T2_SEC*10**9+T2_NS)
RESID=residence_ns<<16
print(f"t3={T3_SEC}.{T3_NS} t2={T2_SEC}.{T2_NS} residence={residence_ns}ns")
resp = reassemble("tx_resp_stream.txt")
exp_resp = full_frame_with_fcs(build_pdelay_resp(CLOCK_ID, PORT_NUM, SRC_MAC, 1,
                               RESID, T2_SEC, T2_NS, REQ_PID))
print("RESP rtl:", resp.hex())
print("RESP exp:", exp_resp.hex())
if bytes(resp)==bytes(exp_resp):
    print("=== Pdelay_Resp: BIT-IDENTICA (corrField+t2+reqPortId+FCS) — PASS ===")
else:
    for j in range(min(len(resp),len(exp_resp))):
        if resp[j]!=exp_resp[j]:
            print(f"RESP difiere byte {j}: {resp[j]:#x} vs {exp_resp[j]:#x}"); break
    raise SystemExit("RESP FALLO")
