package com.bizarre;

import com.android.tools.smali.dexlib2.Opcode;
import com.android.tools.smali.dexlib2.Opcodes;
import com.android.tools.smali.dexlib2.builder.MutableMethodImplementation;
import com.android.tools.smali.dexlib2.builder.instruction.BuilderInstruction11n;
import com.android.tools.smali.dexlib2.builder.instruction.BuilderInstruction11x;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedDexFile;
import com.android.tools.smali.dexlib2.dexbacked.DexBackedMethodImplementation;
import com.android.tools.smali.dexlib2.iface.DexFile;
import com.android.tools.smali.dexlib2.iface.MethodImplementation;
import com.android.tools.smali.dexlib2.rewriter.DexRewriter;
import com.android.tools.smali.dexlib2.rewriter.Rewriter;
import com.android.tools.smali.dexlib2.rewriter.RewriterModule;
import com.android.tools.smali.dexlib2.rewriter.Rewriters;
import com.android.tools.smali.dexlib2.writer.io.MemoryDataStore;
import com.android.tools.smali.dexlib2.writer.pool.DexPool;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;

public class Main {

    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Usage: paccer <apk> <output>");
            System.exit(1);
        }

        String dexPath = args[0];
        String outputPath = args[1];

        try {
            File file = new File(dexPath);
            byte[] fileContent = new byte[(int) file.length()];
            try (FileInputStream fis = new FileInputStream(file)) {
                int bytesRead = 0;
                while (bytesRead < fileContent.length) {
                    int read = fis.read(fileContent, bytesRead, fileContent.length - bytesRead);
                    if (read == -1) break;
                    bytesRead += read;
                }
            }

            ByteArrayInputStream bais = new ByteArrayInputStream(fileContent);
            Opcodes opcodes = Opcodes.getDefault();
            DexBackedDexFile dexFile = DexBackedDexFile.fromInputStream(opcodes, bais);

            DexFile rewritten = patchDex(dexFile);

            MemoryDataStore store = new MemoryDataStore();
            DexPool.writeTo(store, rewritten);

            try (FileOutputStream fos = new FileOutputStream(outputPath)) {
                fos.write(store.getData());
            }
            System.out.println("success");

        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static DexFile patchDex(DexBackedDexFile dexFile) {
        DexRewriter rewriter = new DexRewriter(new RewriterModule() {
            @Override
            public Rewriter<MethodImplementation> getMethodImplementationRewriter(Rewriters rewriters) {
                return new Rewriter<MethodImplementation>() {
                    @Override
                    public MethodImplementation rewrite(MethodImplementation impl) {
                        if (impl instanceof DexBackedMethodImplementation) {
                            DexBackedMethodImplementation methodImpl = (DexBackedMethodImplementation) impl;
                            String methodName = methodImpl.method.getName();
                            String definingClass = methodImpl.method.getDefiningClass();

                            if (methodName.equals("shouldRun") && definingClass.endsWith("/Check;")) {
                                return retFalse();
                            }
                        }
                        return impl;
                    }
                };
            }
        });
        return rewriter.getDexFileRewriter().rewrite(dexFile);
    }

    private static MethodImplementation retFalse() {
        MutableMethodImplementation methodImpl = new MutableMethodImplementation(1);
        methodImpl.addInstruction(new BuilderInstruction11n(Opcode.CONST_4, 0, 0));
        methodImpl.addInstruction(new BuilderInstruction11x(Opcode.RETURN, 0));
        return methodImpl;
    }
}
