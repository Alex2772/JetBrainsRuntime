/*
 * Copyright (c) 2019, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */

import jdk.test.lib.Convert;

import java.security.*;
import java.security.spec.*;
import java.math.*;
import java.util.*;

/*
 * @test
 * @bug 8147502
 * @summary Test that digests are properly truncated before the signature
 *     is applied. The digest should be truncated to the bit length of the
 *     group order.
 * @library /test/lib
 * @build jdk.test.lib.Convert
 * @run main SignatureDigestTruncate
 */
public class SignatureDigestTruncate {

    /*
     * A SecureRandom that produces nextBytes in a way that causes the nonce
     * to be set to the value supplied to the constructor. This class
     * is specific to the way that the native ECDSA implementation in
     * SunEC produces nonces from random input. It may not work for all
     * test cases, and it will need to be updated when the behavior of
     * SunEC changes.
     */
    private static class FixedRandom extends SecureRandom {

        private final byte[] val;

        public FixedRandom(byte[] val) {
            // SunEC adds one to the value returned, so subtract one here in
            // order to get back to the correct value.
            BigInteger biVal = new BigInteger(1, val);
            biVal = biVal.subtract(BigInteger.ONE);
            byte[] temp = biVal.toByteArray();
            this.val = new byte[val.length];
            int inStartPos = Math.max(0, temp.length - val.length);
            int outStartPos = Math.max(0, val.length - temp.length);
            System.arraycopy(temp, inStartPos, this.val, outStartPos,
                temp.length - inStartPos);
        }

        @Override
        public void nextBytes(byte[] bytes) {
            // SunEC samples (n + 1) * 2 bytes, but only n*2 bytes are used by
            // the native implementation. So the value must be offset slightly.
            Arrays.fill(bytes, (byte) 0);
            int copyLength = Math.min(val.length, bytes.length - 2);
            System.arraycopy(val, 0, bytes, bytes.length - copyLength - 2,
                copyLength);
        }
    }

    private static void assertEquals(byte[] expected, byte[] actual,
            String name) {
        if (!Arrays.equals(actual, expected)) {
            System.out.println("expect: "
                    + Convert.byteArrayToHexString(expected));
            System.out.println("actual: "
                    + Convert.byteArrayToHexString(actual));
            throw new RuntimeException("Incorrect " + name + " value");
        }
    }

    private static void runTest(String alg, String curveName,
        String privateKeyStr, String msgStr, String kStr, String sigStr)
        throws Exception {

        byte[] privateKey = Convert.hexStringToByteArray(privateKeyStr);
        byte[] msg = Convert.hexStringToByteArray(msgStr);
        byte[] k = Convert.hexStringToByteArray(kStr);
        byte[] expectedSig = Convert.hexStringToByteArray(sigStr);

        AlgorithmParameters params = AlgorithmParameters.getInstance("EC");
        params.init(new ECGenParameterSpec(curveName));
        ECParameterSpec ecParams =
            params.getParameterSpec(ECParameterSpec.class);

        KeyFactory kf = KeyFactory.getInstance("EC");
        BigInteger s = new BigInteger(1, privateKey);
        ECPrivateKeySpec privKeySpec = new ECPrivateKeySpec(s, ecParams);
        PrivateKey privKey = kf.generatePrivate(privKeySpec);

        Signature sig = Signature.getInstance(alg);
        sig.initSign(privKey, new FixedRandom(k));
        sig.update(msg);
        byte[] computedSig = sig.sign();
        assertEquals(expectedSig, computedSig, "signature");
    }

    public static void main(String[] args) throws Exception {
        runTest("SHA384withECDSAinP1363Format", "sect283r1",
            "abcdef10234567", "010203040506070809",
            "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d" +
            "1e1f20212223",
            "01d7544b5d3935216bd45e2f8042537e1e0296a11e0eb96666199281b409" +
            "42abccd5358a035de8a314d3e6c2a97614daebf5fb1313540eec3f9a3272" +
            "068aa10922ccae87d255c84c");
    }
}
