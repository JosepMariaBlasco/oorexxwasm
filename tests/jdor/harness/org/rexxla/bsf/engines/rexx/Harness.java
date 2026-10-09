package org.rexxla.bsf.engines.rexx;
import java.util.*;
import java.nio.file.*;
// java -cp . org.rexxla.bsf.engines.rexx.Harness commands.txt : runs JDOR commands (one per line)
public class Harness {
    public static List<String> out = null;
    public static List<String> errors = new ArrayList<>();
    public static List<String> conditions = new ArrayList<>();
    public static Map<String,Object> vars = new HashMap<>();
    public static void main(String[] a) throws Exception {
        System.setProperty("java.awt.headless", "true");
        if (a.length > 1 && a[1].equals("-o")) out = new ArrayList<>();
        RexxRedirectingCommandHandler h = (RexxRedirectingCommandHandler)
            Class.forName("org.oorexx.handlers.jdor.JavaDrawingHandler").getDeclaredConstructor().newInstance();
        for (String line : Files.readAllLines(Paths.get(a[0]))) {
            String w = line.trim().split("\\s+")[0].toUpperCase();
            if (w.startsWith("WIN") || w.equals("SLEEP") || w.equals("PRINTIMAGE")) continue;
            int nc = conditions.size();
            Object r = h.handleCommand(null, "JDOR", line);
            vars.put("RC", r == null ? "0" : r);
            if (a.length > 2 || conditions.size() > nc)
                System.out.println("[" + line + "] -> " + (conditions.size() > nc ? conditions.get(nc) : r));
        }
        for (String e : errors) System.out.println("E: " + e);
        if (out != null) for (String s : out) System.out.println("O: " + s);
    }
}
