package org.rexxla.bsf.engines.rexx;
import java.util.*;
// stub of BSF4ooRexx's interface: the Harness supplies the Rexx side
public interface RexxRedirectingCommandHandler {
    Object handleCommand(Object slot, String address, String command);
    default boolean isInputRedirected(Object slot) { return false; }
    default String readInput(Object slot) { return null; }
    default boolean isOutputRedirected(Object slot) { return Harness.out != null; }
    default void writeOutput(Object slot, String s) { if (Harness.out != null) Harness.out.add(s); }
    default boolean isErrorRedirected(Object slot) { return true; }
    default void writeError(Object slot, String s) { Harness.errors.add(s); }
    default Object getContextVariable(Object slot, String name) { return Harness.vars.get(name.toUpperCase()); }
    default void setContextVariable(Object slot, String name, Object v) { Harness.vars.put(name.toUpperCase(), v); }
    default Object getCallerContext(Object slot) { return new RexxProxy("context"); }
    default void raiseCondition(Object slot, String type, String cmd, Object[] add, Object rc) { Harness.conditions.add(type + " " + rc); }
    default boolean checkCondition(Object slot) { return false; }
    default Object getNil(Object slot) { return null; }
    default Object newStringTable(Object slot) { return new RexxProxy("StringTable"); }
}
