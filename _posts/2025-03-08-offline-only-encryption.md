---
layout: post
title: "Offline Encryption Using WebAuthn"
date: 2025-03-08
---

I've been diving deep into browser-based cryptography lately, and let me tell you, implementing truly secure offline encryption is about as straightforward as teaching quantum physics to a goldfish. The core problem? Getting consistent key material across sessions without storing anything sensitive.

After countless late nights of cursing at my keyboard and several "why am I doing this to myself" moments, I stumbled upon an intriguing solution: leveraging WebAuthn (e.g. those little USB security keys like YubiKey) not just for authentication, but as a source of encryption key material.

## The Encryption Challenge

Let's be real - creating secure encryption that works completely offline in a browser environment is a nightmare for several reasons:

- Your key material needs to be consistent across browser sessions
- You can't just derive keys from code (that's basically security through obscurity)
- Browser storage is about as secure as a paper lock on a bank vault
- And of course, the whole thing needs to work offline (otherwise, what's the point?)

After banging my head against various approaches (including some truly questionable experiments with IndexedDB), I realized WebAuthn might be the perfect solution. Why? Because those little hardware authenticators never expose their private keys - they're basically tiny HSMs that live in your USB port!

## WebAuthn: Not Just for Logins Anymore

WebAuthn wasn't designed to be a "key extractor" - it's an authentication standard. But with a bit of creative thinking (and some cryptographic sleight of hand), we can use it to generate consistent encryption material.

Here's how it works in a nutshell:

1. **Register a credential** (one-time setup)
2. **Store the credential ID** (not secret, so browser storage is fine)
3. **Get an assertion** using a fixed challenge whenever you need key material
4. **Use the signature** as input for your encryption key derivation

The real magic here is that for a given credential and challenge, the hardware authenticator will produce a signature that we can use as key material. The private key never leaves the device!

## Show Me the Code!

Here's how to implement the registration phase:

```js
// A randomly generated challenge (only used during registration)
const challenge = window.crypto.getRandomValues(new Uint8Array(32));

// Configure your publicKeyCredentialCreationOptions
const publicKeyOptions = {
  challenge: challenge,
  rp: { name: "Offline Demo RP" },
  user: {
    id: Uint8Array.from("unique-user-id", c => c.charCodeAt(0)),
    name: "demo-user",
    displayName: "Demo User"
  },
  pubKeyCredParams: [{ type: "public-key", alg: -7 }], // ECDSA with SHA-256
  timeout: 60000,
  attestation: "none"
};

navigator.credentials.create({ publicKey: publicKeyOptions })
  .then(cred => {
    // Save the credential ID for future assertions
    const credId = new Uint8Array(cred.rawId);
    // Persist credId (e.g., in IndexedDB)
    console.log("Registration done, credentialId:", bufferToBase64Url(credId));
  })
  .catch(err => {
    console.error(err);
  });

function bufferToBase64Url(buffer) {
  const str = String.fromCharCode(...new Uint8Array(buffer));
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
```

And here's the really interesting part - getting key material later:

```js
// Retrieve the previously saved credentialId
const savedCredId = /* retrieve your stored credentialId */;
const credIdBuffer = base64UrlToBuffer(savedCredId);

// Use a deterministically derived challenge
const fixedChallenge = new Uint8Array([ /* 32 bytes of fixed challenge data */ ]);

const publicKeyRequestOptions = {
  challenge: fixedChallenge,
  allowCredentials: [{
    id: credIdBuffer,
    type: "public-key",
  }],
  userVerification: "discouraged",
  timeout: 60000
};

navigator.credentials.get({ publicKey: publicKeyRequestOptions })
  .then(assertion => {
    // Extract the signature
    const signature = new Uint8Array(assertion.response.signature);
    
    // Combine with additional secret entropy
    // const combinedMaterial = concat(signature, additionalEntropy);
    // const rawKeyMaterial = await deriveRawKeyMaterial(combinedMaterial);
    
    console.log("Obtained signature for key derivation:", signature);
    // Continue with key derivation...
  })
  .catch(err => {
    console.error(err);
  });

function base64UrlToBuffer(base64UrlString) {
  const base64 = base64UrlString.replace(/-/g, '+').replace(/_/g, '/');
  const pad = base64.length % 4;
  const padded = pad ? base64 + "=".repeat(4 - pad) : base64;
  const binary = atob(padded);
  const buffer = new Uint8Array(binary.length);
  Array.from(binary).forEach((char, i) => buffer[i] = char.charCodeAt(0));
  return buffer;
}
```

## But Wait, There's a Catch!

Of course there is. When is crypto ever straightforward?

Some authenticators don't produce deterministic signatures for the same input. They might:
1. Use non-deterministic signature algorithms (looking at you, ECDSA)
2. Embed signature counters in the output
3. Do other vendor-specific weird stuff

This means that your key material might change slightly between uses. Not ideal for encryption!

Enter the **fuzzy extractor** - a cryptographic primitive that takes "noisy" input and reliably produces consistent output. It's like having a friend who always tells the same version of a story, even when you keep changing the details slightly each time.

A typical fuzzy extractor has two phases:
1. **Generate**: Takes initial input, produces a key and a "helper"
2. **Reproduce**: Uses the helper to recover the same key from slightly different input

## Security Considerations: The JavaScript Memory Problem

Let's talk about the elephant in the room: JavaScript memory.

Since all your variables in JavaScript are potentially accessible to attackers with debugging capabilities, your signature values could be exposed if someone can run a debugger or inject code through XSS.

Some mitigation strategies:
1. Keep sensitive variables around for as short a time as possible
2. Use Web Crypto APIs which operate outside typical JavaScript memory
3. Implement strict Content Security Policies
4. Clear sensitive data ASAP

And for extra security, consider:
1. Adding user-provided entropy (like a password) to your key derivation
2. Never, ever, ever storing sensitive key material in browser storage
3. Considering the security of the device itself in your threat model

## Wrapping Up

So there you have it - WebAuthn hardware authenticators can be cleverly repurposed as key material providers for offline encryption. The private key stays safely locked away in hardware, your encryption keys become consistently derivable without network connectivity, and you get to feel like a crypto wizard in the process.

I've been using this technique successfully in a few personal projects, and while it's definitely not the most conventional approach, it's been surprisingly robust in practice. The combination of hardware security and fully offline operation makes it a winner for certain types of applications.

Give it a try in your next offline encryption project, and let me know if you come up with any clever improvements to the technique! Just remember - no crypto system is perfect, so always consider your specific threat model and use case.

P.S. Huge thanks to the WebAuthn standard creators - I'm pretty sure this wasn't what they had in mind, but that's the beauty of well-designed crypto primitives: they enable use cases the designers never even imagined!
