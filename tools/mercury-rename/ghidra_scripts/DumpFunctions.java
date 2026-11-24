// DumpFunctions.java — Ghidra headless script for mercury-rename.
//
// Decompiles every function in the loaded program and dumps one JSON
// object per function to the file given as the first script argument:
//
//   {
//     "binary": "<program name>",
//     "functions": [
//       {
//         "address": "0x1000",          // entry-point offset, hex
//         "name": "FUN_00101000",       // current symbol name
//         "is_external": false,         // true for imported/PLT stubs
//         "is_thunk": false,
//         "signature": "undefined FUN_00101000(int, char *)",
//         "decompile_ok": true,
//         "decompiled_c": "undefined FUN_00101000(...) { ... }",
//         "strings": ["ro.backlight", ...],   // string data referenced
//         "callers": ["0x2000", ...],         // entry points that call here
//         "callees": ["0x3000", ...]          // entry points called from here
//       }, ...
//     ]
//   }
//
// Run via analyzeHeadless (see tools/mercury-rename/README.md):
//   analyzeHeadless <projdir> <proj> -import <file.so> \
//       -postScript DumpFunctions <out.json> \
//       -scriptPath <tools/mercury-rename/ghidra_scripts> -deleteProject
//
// Decompile failures are recorded (decompile_ok=false) and never abort
// the dump. JSON is written by hand (no JSON library is guaranteed to
// be on the headless classpath) with full escaping.

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.InstructionIterator;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;

import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public class DumpFunctions extends GhidraScript {

    private static final int DECOMPILE_TIMEOUT_SECONDS = 60;
    private static final int MAX_STRINGS_PER_FUNCTION = 50;
    private static final int MAX_CALLERS_CALLEES = 200;

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            throw new IllegalArgumentException(
                    "DumpFunctions: first script argument must be the output JSON path");
        }
        String outPath = args[0];

        FunctionManager fm = currentProgram.getFunctionManager();
        Listing listing = currentProgram.getListing();

        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);

        int total = 0;
        int decompiled = 0;
        StringBuilder json = new StringBuilder();
        json.append("{\n  \"binary\": ").append(q(currentProgram.getName())).append(",\n");
        json.append("  \"functions\": [");

        FunctionIterator it = fm.getFunctions(true);
        boolean first = true;
        while (it.hasNext()) {
            Function func = it.next();
            total++;
            if (!first) {
                json.append(",");
            }
            first = false;
            json.append("\n    {");
            json.append("\n      \"address\": ").append(q(addrHex(func.getEntryPoint())));
            json.append(",\n      \"name\": ").append(q(func.getName()));
            json.append(",\n      \"is_external\": ").append(func.isExternal());
            json.append(",\n      \"is_thunk\": ").append(func.isThunk());
            json.append(",\n      \"signature\": ").append(q(safeSignature(func)));

            String decompiledC = null;
            boolean ok = false;
            try {
                DecompileResults res = decompiler.decompileFunction(
                        func, DECOMPILE_TIMEOUT_SECONDS, monitor);
                if (res != null && res.getDecompiledFunction() != null) {
                    decompiledC = res.getDecompiledFunction().getC();
                    ok = decompiledC != null;
                }
            } catch (Exception e) {
                // Recorded below as decompile_ok=false; never abort the dump.
                println("DumpFunctions: decompile failed for "
                        + func.getName() + ": " + e.getMessage());
            }
            if (ok) {
                decompiled++;
            }
            json.append(",\n      \"decompile_ok\": ").append(ok);
            json.append(",\n      \"decompiled_c\": ")
                    .append(ok ? q(decompiledC) : "null");

            json.append(",\n      \"strings\": ")
                    .append(stringArrayJson(referencedStrings(func, listing)));
            json.append(",\n      \"callers\": ")
                    .append(addrArrayJson(callingFunctions(func)));
            json.append(",\n      \"callees\": ")
                    .append(addrArrayJson(calledFunctions(func)));
            json.append("\n    }");
        }

        json.append("\n  ]\n}\n");
        decompiler.dispose();

        try (PrintWriter out = new PrintWriter(new FileWriter(outPath))) {
            out.print(json.toString());
        }
        println("DumpFunctions: wrote " + total + " functions ("
                + decompiled + " decompiled) to " + outPath);
    }

    // -- helpers -----------------------------------------------------------

    private String addrHex(Address addr) {
        return "0x" + Long.toHexString(addr.getOffset());
    }

    private String safeSignature(Function func) {
        try {
            return func.getSignature().toString();
        } catch (Exception e) {
            return func.getName() + "(...)";
        }
    }

    /** Strings in data referenced from inside this function (capped). */
    private List<String> referencedStrings(Function func, Listing listing) {
        List<String> out = new ArrayList<>();
        try {
            AddressSetView body = func.getBody();
            InstructionIterator instrs = listing.getInstructions(body, true);
            while (instrs.hasNext() && out.size() < MAX_STRINGS_PER_FUNCTION) {
                Instruction instr = instrs.next();
                Reference[] refs = getReferencesFrom(instr.getMinAddress());
                for (Reference ref : refs) {
                    if (out.size() >= MAX_STRINGS_PER_FUNCTION) {
                        break;
                    }
                    Data data = getDataAt(ref.getToAddress());
                    if (data != null && data.hasStringValue()) {
                        Object value = data.getValue();
                        if (value != null) {
                            String s = value.toString();
                            if (!s.isEmpty() && !out.contains(s)) {
                                out.add(s);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Best effort only; a missing string list never fails the dump.
            println("DumpFunctions: string scan failed for "
                    + func.getName() + ": " + e.getMessage());
        }
        return out;
    }

    private List<String> callingFunctions(Function func) {
        List<String> out = new ArrayList<>();
        try {
            Set<Function> callers = func.getCallingFunctions(monitor);
            for (Function caller : callers) {
                if (out.size() >= MAX_CALLERS_CALLEES) {
                    break;
                }
                out.add(addrHex(caller.getEntryPoint()));
            }
        } catch (Exception e) {
            // Best effort only.
        }
        return out;
    }

    private List<String> calledFunctions(Function func) {
        List<String> out = new ArrayList<>();
        try {
            Set<Function> callees = func.getCalledFunctions(monitor);
            for (Function callee : callees) {
                if (out.size() >= MAX_CALLERS_CALLEES) {
                    break;
                }
                out.add(addrHex(callee.getEntryPoint()));
            }
        } catch (Exception e) {
            // Best effort only.
        }
        return out;
    }

    private String stringArrayJson(List<String> values) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < values.size(); i++) {
            if (i > 0) {
                sb.append(", ");
            }
            sb.append(q(values.get(i)));
        }
        sb.append("]");
        return sb.toString();
    }

    private String addrArrayJson(List<String> values) {
        return stringArrayJson(values);
    }

    /** JSON string literal with full escaping (no JSON library assumed). */
    private static String q(String s) {
        if (s == null) {
            return "null";
        }
        StringBuilder sb = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                case '\b': sb.append("\\b"); break;
                case '\f': sb.append("\\f"); break;
                default:
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
            }
        }
        sb.append("\"");
        return sb.toString();
    }
}
