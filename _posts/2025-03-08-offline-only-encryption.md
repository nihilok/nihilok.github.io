---
layout: post
title: "Offline Encryption Using WebAuthn"
date: 2025-03-08
---

Below is a conversation I had with OpenAI's `o3-mini` model on the topic of offline encryption. The conversation covers various aspects of offline encryption, including key generation, secure storage, and the use of WebAuthn for key derivation. The conversation also touches on the use of fuzzy extractors for normalizing key material and the security implications of exposing sensitive data in JavaScript variables:

> How can I use the Web Authentication API on the client side only (completely offline) to generate key material that I can use (with added entropy) to derive a CryptoKey.
Don't worry about the crypto implementation, just the webauthn side of things. The key material needs to be consistent across authentication assertions, but also to be someth
ing that an attacker can not derive from the code alone, or from anything stored in insecure browser storage.

Below is one approach you can take—bearing in mind that WebAuthn wasn’t designed as a “key‐extractor” but rather as an authentication mechanism where secret signing keys remain inside secure authenticators. In other words, you cannot ever extract the private key material from a WebAuthn device. However, you *can* use the signing “oracle” provided by an authenticator to produce data that you combine (for example, by hashing it with other secret entropy you supply) into a key you then derive using Web Crypto. The following outlines one method to do this entirely on the client (offline), with some important caveats.

---

### What You Want to Achieve

- **Consistency:** You want a piece of key material that is reproducible whenever you run an “assertion” (even though the private key never leaves the authenticator).
- **Secrecy:** An attacker should not be able to derive the key material just from the code or from browser‐local (insecure) storage.
- **Offline:** You want to do all of this on the client without any network calls.

### The General Plan

1. **Make a Credential (Registration) Once:**
   Use `navigator.credentials.create()` to register a credential with your offline “Relying Party” parameters.
   Save the returned credential’s ID (for later use) in some persistent storage (which you assume is “secure enough” for a reference; you are not storing secret key material, just an identifier).

2. **Produce a Consistent “Signature” (Assertion) Later:**
   When you wish to create your key material again, call `navigator.credentials.get()` with a _fixed challenge_ (or, more accurately, a challenge that you deterministically derive from a stable input and maybe a salt kept out of reach of attackers).
   The authenticator will use its private key—and possibly (but not necessarily) a deterministic signature algorithm—to sign your challenge. *(Note: Some signature schemes may inject randomness. If your authenticator produces non‐deterministic signatures, you might get different outputs on the same challenge. In that case, you must ensure determinism by, for example, using a key derivation function that “stabilizes” a variable-length signature input together with your added entropy.)*

3. **Combine with Added Entropy and Derive Your CryptoKey:**
   Once you have a signature (the raw bytes returned as part of the assertion response), combine it with other secret or high‐entropy data (which you control) and then feed it to a key derivation function (for example, using HKDF in Web Crypto) to produce your final `CryptoKey`.

---

### Example Code Sketch

Below is an example sketch that focuses on the WebAuthn parts. (The actual cryptographic key derivation is left as a “don’t worry about it” piece.)

#### Registration (One Time)

```js
// A randomly generated challenge (only used during registration)
const challenge = window.crypto.getRandomValues(new Uint8Array(32));

// Configure your publicKeyCredentialCreationOptions (customize as needed)
const publicKeyOptions = {
  challenge: challenge,
  rp: { name: "Offline Demo RP" },
  user: {
    id: Uint8Array.from("unique-user-id", c => c.charCodeAt(0)),
    name: "demo-user",
    displayName: "Demo User"
  },
  pubKeyCredParams: [{ type: "public-key", alg: -7 }], // ECDSA with SHA-256, for example
  timeout: 60000,
  attestation: "none"
};

navigator.credentials.create({ publicKey: publicKeyOptions })
  .then(cred => {
    // Save the credential ID for future assertions.
    // Since this is not secret (it only references a key stored in hardware), storing it in IndexedDB or similar is acceptable.
    const credId = new Uint8Array(cred.rawId);
    // Persist credId (e.g., in IndexedDB or other protected storage)
    console.log("Registration done, credentialId:", bufferToBase64Url(credId));
  })
  .catch(err => {
    console.error(err);
  });

// ---
// Helper function to convert buffer to Base64URL (if needed)
function bufferToBase64Url(buffer) {
  const str = String.fromCharCode(...new Uint8Array(buffer));
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
```

#### Assertion (Authentication) & Extracting Key Material

```js
// Suppose you previously saved and can retrieve the credentialId
// For demonstration, assume we have it as a Base64URL string.
const savedCredId = /* retrieve your stored credentialId in Base64URL format */;
const credIdBuffer = base64UrlToBuffer(savedCredId);

// Use a deterministically derived challenge
// For consistency, you may use a fixed challenge (or a challenge derived from an offline secret-salt and counter)
const fixedChallenge = new Uint8Array([ /* 32 bytes of fixed challenge data */ ]);

// WebAuthn assertion options for authentication
const publicKeyRequestOptions = {
  challenge: fixedChallenge,
  allowCredentials: [{
    id: credIdBuffer,
    type: "public-key", // Must match the credential type
    // transports: [ ... ] // Optionally list allowed transports (if necessary)
  }],
  userVerification: "discouraged", // Since this is offline, you might not require additional UI/biometric verification
  timeout: 60000
};

navigator.credentials.get({ publicKey: publicKeyRequestOptions })
  .then(assertion => {
    // Extract the signature from the assertion.
    // The signature is an ArrayBuffer.
    const signature = new Uint8Array(assertion.response.signature);

    // At this point, 'signature' is the authenticator’s signature over your fixed challenge.
    // IMPORTANT: Depending on the algorithm and authenticator, this signature might not be exactly the same every time.
    // If it is non-deterministic, consider applying a key derivation function that “normalizes” the input.

    // Combine with additional secret entropy (which you hold in memory or secure storage not accessible to attackers)
    // For example:
    //   const combinedMaterial = concat(signature, additionalEntropy);
    //   const rawKeyMaterial = await deriveRawKeyMaterial(combinedMaterial);
    //   const cryptoKey = await window.crypto.subtle.importKey(..., rawKeyMaterial, ...);

    console.log("Obtained signature for key derivation:", signature);

    // Continue with your custom derivation to yield a CryptoKey...
  })
  .catch(err => {
    console.error(err);
  });

// ---
// Helper function to convert Base64URL to ArrayBuffer
function base64UrlToBuffer(base64UrlString) {
  // Convert from Base64URL to standard Base64 string.
  const base64 = base64UrlString.replace(/-/g, '+').replace(/_/g, '/');
  const pad = base64.length % 4;
  const padded = pad ? base64 + "=".repeat(4 - pad) : base64;
  const binary = atob(padded);
  const buffer = new Uint8Array(binary.length);
  Array.from(binary).forEach((char, i) => buffer[i] = char.charCodeAt(0));
  return buffer;
}
```

---

### Points to Consider

- **Determinism of Signatures:**
  Some authenticators (or the underlying signature algorithms) might incorporate nonces (or follow RFC6979’s deterministic signing) so that the same challenge produces exactly the same signature over repeated invocations. You must verify that your target authenticators produce the consistency you require. If not, you might have to “normalize” the variability by, for example, using a key derivation function that produces consistent output even if the raw signature has (for example) a counter value or ephemeral randomness encoded.

- **Challenge Management:**
  Normally, challenges in WebAuthn are randomized on the server side to prevent replay attacks. Here, since you are offline and wish for consistency, you’ll likely use a fixed challenge (or a challenge derived in a reproducible way out of a secret stored securely on the device). Just be aware that using a fixed challenge could have security implications in a real online setting—but for offline key-generation it may be acceptable if combined with additional secret entropy that is not stored in unsafe locations.

- **Security of Added Entropy:**
  Because the signature alone may not be “secret enough” (it is produced deterministically by hardware and typically is not extractable in a raw form), you must mix in additional entropy (for example, input provided by the user or securely stored data) to “salt” your key derivation. This added entropy should come from a source not accessible to an attacker.

---

### In Summary

Even though you cannot extract the private key from a WebAuthn authenticator, you can use its signing operation as a “black box” to generate a response that—when mixed with locally kept entropy and processed through a key derivation function—yields a consistent and secure `CryptoKey`. The key steps are:

1. Register a credential with WebAuthn and store its identifier.
2. Later, issue an assertion using a fixed (or deterministically derived) challenge.
3. Take the resulting signature (or a combination thereof) and mix it with your own added entropy.
4. Feed the result into a key derivation function to produce your usable key.

This method keeps the secret portion (the private key) inside your authenticator and only uses the proven cryptographic operation of signing as an ingredient in your overall key derivation pipeline.

Feel free to adjust the details (for example, how you derive the fixed challenge and additional entropy, and which key derivation function you use) to best suit your security model.

> What algorithm could I use to normalise material with a counter value or ephemeral randomness?


In practice you’ll need an approach that “extracts” the stable, high‐entropy bits from your input while “smoothing over” any variable parts. A standard tool for this is a **fuzzy extractor**.

---

### Fuzzy Extractors in a Nutshell

A fuzzy extractor is designed to take “noisy” input (data that varies slightly between readings, like biometric measurements or any signature value with ephemeral randomness or counter values) and reliably produce a consistent, uniform cryptographic key. It typically does this in two phases:

1. **Generate:** Takes the noisy input and produces a uniformly random key plus a helper (public) string.
2. **Reproduce:** Later, when you have a slightly different version of the input, you use the helper string to recover the same key.

The helper string does not reveal significant information about the key but helps correct the differences between noisy readings.

For your use case, if your authenticator’s signature output (or some derived value) includes a counter or other ephemeral randomness that causes slight differences between invocations, you’d feed that value into a fuzzy extractor. The output would then be a normalized key material that is robust against the noise.

---

### Alternative: Deterministic Extraction via Standard KDFs

If the deviation is not “fuzzy” (i.e. if you know exactly which parts of the output are non-deterministic, such as a counter value in a well‐defined format) you might be able to strip or disregard the variable portions before applying a Key Derivation Function such as the HMAC-based Extract-and-Expand Key Derivation Function (**HKDF**). However, if you cannot easily “subtract” the noisy bits or if the noise is inherent and unpredictable, a fuzzy extractor is a more principled approach.

---

### Summary Recommendation

- **Fuzzy Extractor:** Use this if you’re dealing with truly noisy data (e.g., signatures that include ephemeral randomness or counter values that vary slightly between operations) and you want to reliably derive the same key.
- **HKDF or similar KDF:** Use these if you can isolate and remove the non-deterministic parts (or if your authenticator produces fully deterministic signatures when fed a fixed challenge).

For many scenarios where you must “normalize” material from hardware that injects randomness, the fuzzy extractor model (as introduced by Dodis, Reyzin, and Smith in “Fuzzy Extractors: How to Generate Strong Keys from Biometrics and Other Noisy Data”) is the algorithmic approach to consider.

By applying such an algorithm, you’d combine the signature output (which may be “noisy”) with your additional local entropy to derive a consistent CryptoKey that remains secure against attackers who only see the code or insecure storage.

In many cases—especially with common passkey setups like 1Password in Chromium-based browsers—you’ll observe that a fixed challenge yields the exact same signature every time. This indicates that the authenticator is working in a deterministic manner (or is using a deterministic variant like RFC6979 for ECDSA), so there’s no variation (or “noise”) in the output that needs to be normalized.

That said, some authenticators (or signature algorithms) may include additional non-deterministic elements such as an ephemeral nonce or a counter (often used to detect cloned credentials). Here are some pointers on when and how such variability might arise and how you’d prepare inputs for a fuzzy extractor in those scenarios:

---

### When Might Variability Occur?

1. **Non-Deterministic Signature Algorithms:**
   Some implementations of signature algorithms (like ECDSA without RFC6979) generate a new random nonce for each signature. Even if the same challenge is given, the signature may differ because of the randomness.

2. **Signature Counters:**
   The WebAuthn spec defines a signature counter in the authenticator data. This counter is included (or at least used) to help detect cloned authenticators. If the authenticator embeds the counter directly into the signed data or if the output format changes slightly because of the counter, then repeated operations may yield outputs that differ only in that field.

3. **Authenticator Implementation Details:**
   Different authenticator vendors may design their devices differently. Some may guarantee deterministic responses when issued the same challenge, while others may purposely include ephemeral elements (e.g., for enhanced side‐channel resistance).

---

### Deciding What to Feed into a Fuzzy Extractor

If you determine (by experiment or documentation review) that your authenticator’s signature output contains parts that vary (for example, the counter or ephemeral randomness), you’ll need to devise a way to “extract” the stable, high-entropy components. Here are some approaches:

- **Analyze the Output Structure:**
  Look at the raw output of the authenticator. If it’s, say, an ASN.1 DER-encoded ECDSA signature, you might be able to identify which components (such as the \(r\) value) are constant versus which (like \(s\)) are influenced by a nonce or counter.
  - *Example:* If you see that only a particular field in the signature changes, you might decide to strip out that variable part before using the result as input to your key derivation.

- **Use the Fuzzy Extractor on the Entire Output:**
  When it isn’t feasible to isolate the noise or when the “noise” is spread over the whole output, you can feed the entire signature into a fuzzy extractor. The extractor is designed to tolerate a certain amount of variability (up to a defined “distance”) and still reproduce the same key material.
  - In this case, you might want to run experiments—collect several signatures under identical conditions—to quantify the variability, then calibrate your fuzzy extractor’s error tolerance accordingly.

- **Combine with Additional Entropy:**
  Sometimes, you might mix the signature with additional locally stored secret entropy in a way that “masks” the variability before applying a standard KDF (like HKDF). This can help if the scoring out of the authenticator is only slightly variable.

---

### Practical Considerations

- **No Variation Observed:**
  In your case, with 1Password and Chromium, if you observe that given the same challenge the signature is always the same, then you’re not encountering any ephemeral randomness or counter issues in that environment. In that scenario, you probably don’t need a fuzzy extractor at all—the output is already normalized.

- **Cross-Platform or Future Proofing:**
  If you plan to support a variety of authenticators or wish to be resilient to future changes (where a device might introduce nondeterminism), you might choose to design your system so that the output is always fed into a fuzzy extraction process. In this design, you’d run tests to measure which bits consistently match and which vary, then feed the entire signature (or just the “stable subset” if you can isolate it) into the fuzzy extractor.

- **Documentation and Vendor Guidance:**
  Sometimes, the authenticator manufacturer or the FIDO Alliance documentation will describe whether an authenticator uses a counter in the signed data or how they generate the nonce. That documentation can inform you as to what variability to expect.

---

### Summary

- **With Deterministic Behavior:** If your experiments show the signature is consistent with the same challenge, then the material you feed into your derivation function is stable and you don’t really need a fuzzy extractor.
- **With Variability:** If you detect variability (for example, if you notice that a counter increases or a nonce changes), you need to either isolate the stable parts manually or use a fuzzy extractor that can “correct” the small differences between signatures.
- **What to Feed:**
  - If deterministic: The raw signature bytes (or a processed version thereof) can be used directly (possibly after mixing with additional entropy).
  - If non-deterministic: The full signature output (or the subset of bits that hold the stable keying material) becomes the input to your fuzzy extractor, which then produces a consistent output that you use to derive your CryptoKey.

By characterizing your authenticator’s output through experimentation (and checking any available documentation), you can decide whether or not you need the fuzzy extraction step and exactly which bytes of the response should be used as the input.

> Say I have the signature referenced by a variable in JavaSript.. could an attacker use a debugger to read the value?

The short answer is: **if an attacker can execute or inspect code on your system (for example, through debugging tools, compromised browser extensions, or an XSS vulnerability), then yes—they could potentially read the value of that variable.**

---

### More Detailed Considerations

1. **JavaScript Environment:**
   When your code runs in the browser, all variables (including one holding a signature) exist in memory and are accessible to the running JavaScript environment. If an attacker is able to inject code (via XSS) or if they have control over the browser’s debugging tools (e.g., through developer consoles on an already-compromised device), then they might read these variables.

2. **Debugger Attacks:**
   Modern browsers provide developer tools that can inspect in-memory variables. If someone has physical access to your machine or if an attacker’s code is running in the same context (for example, from a malicious browser extension), then they could potentially use these tools to read out sensitive variables.

3. **Threat Model:**
   In a typical secure web application, you assume that the client environment won’t be compromised. However, if an attacker compromises the browser or the environment (through malware, malicious extensions, or injected scripts), then any secret material stored or processed in JavaScript can be at risk.

4. **Mitigation Strategies:**
   - **Minimize Exposure:**
     Once the signature (or any sensitive value) has been used for its purpose (e.g., for key derivation), consider overwriting or removing it from memory (though JavaScript’s garbage collection may not guarantee immediate erasure).
   - **Secure Coding Practices:**
     Evaluate your threat model and assume that if an attacker already has the ability to inspect runtime variables on your client, they might be able to compromise other parts of the system as well.
   - **Use Web Crypto:**
     When handling cryptographic material, offload as much of the operations as possible to the browser’s Web Crypto APIs. These operations are more likely to be implemented in native code outside typical JavaScript memory space, which in some cases makes it more challenging for attackers to inspect live key materials.
   - **Secure the Context:**
     Prevent cross-site scripting vulnerabilities and restrict the use of untrusted scripts. Use Content Security Policy (CSP) headers, secure sandboxing, and ensure that only trusted code executes in your application.

---

### Summary

- **Yes,** if an attacker can forcefully inspect your JavaScript execution—for instance, through a debugger or malicious code injection—then the value (such as the signature) stored in a variable might be read.
- **Defense:**
  Preventing such access involves hardening the client against typical web vulnerabilities (like XSS), using secure browser features (like Web Crypto), and adopting a strict security model.
- **Practical Note:**
  In a scenario where a user’s machine or browser is completely compromised, almost all strategies fall short because the attacker already controls the environment. Therefore, the assumption is that if an attacker has access to the debugging interface, the entire device’s security is in jeopardy.

By following secure coding practices and reducing the window of exposure for sensitive information, you can minimize—but not completely eliminate—the risk under the assumption that the client environment remains uncompromised.
