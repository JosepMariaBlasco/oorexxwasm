package org.rexxla.bsf.engines.rexx;
import org.apache.bsf.BSFException;
public class RexxProxy {
    String what;
    public RexxProxy(String what){ this.what=what; }
    public Object sendMessage0(String m) throws BSFException {
        switch (m.toUpperCase()) {
            case "LINE": return "0";
            case "NAME": return "harness";
            case "ID": return "Routine";
            default: return new RexxProxy(m);
        }
    }
    public Object sendMessage2(String m, Object a, Object b) throws BSFException { return null; }
}
