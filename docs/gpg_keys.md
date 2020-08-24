Notes on updating or revoking GPG keys

First a note about terminology. A potentially confusing thing with GPG is the overloaded meanings of terms. It is probably helpful to state up front that this system operates on collections of associated identities and credentials. Often an entire such collection is referred to as a 'key' or a 'keypair', while keys inside the collection are also called keys and keypairs. Here I'll try and say "key bundle" when referring to the whole collection, but you probably won't see that term used elsewhere in the worlds of GPG and PGP.

A key bundle consists of:
- A 'master' or 'primary' keypair (private + public key)
- Zero or more 'subordinate keypairs', often shortened to 'subordinate keys' or 'subkeys'.
- Zero or more 'user ids' (strings of the form "FirstName LastName (comment) <email@provider>")
- Zero or more key signatures
 - For example, a signature by the private primary key of the public primary key
   ...or cross-signatures in both directions between the primary keypair and subordinate keypairs
   ...or signatures on the user ids by the primary private key
- Zero or more 'revocation certificates', revoking any of the signatures mentioned above

When publishing or retrieving something to or from the key server network, these key bundles are the units you are working with. Publishing a key bundle is a create/update operation. In the 'update' case the key bundle gets merged with older copies of that key bundle. A merge operation will combine fields from the key bundles being merged.

It is possible to delete pieces from a key bundle, but that is probably not what you want, since they might well reappear after the updated key is published and merged throughout the key server network. Instead, add a revocation for the thing you might have wanted to remove. 


- Publish a key bundle to the key server network
 gpg --send-keys (fingerprint)
 - Then we want clients to get the updated key bundle
  - For clients using gpg directly that might be done with:
   gpg --refresh-keys
  - For clients using gpg via apt that might be done with:
   sudo apt-key adv --refresh-keys

- If a subkey expires
 - Use master key to generate a new subkey
  gpg --edit-key (fingerprint) gives a prompt; then use 'addkey' subcommand at prompt
  - subkey is added to key bundle
 - See 'Publish a key bundle to the key server network' above

- If a subkey is compromised
 - Use master key to generate a revocation certificate for that subkey
  gpg --edit-key (fingerprint) gives a prompt; then use 'revkey' subcommand at prompt
  - revocation certificate is added to key bundle
 - See 'Publish a key bundle to the key server network' above

- Before master/primary key expires
 - Although GPG key bundles have expiration times, these can be extended using the private master key
 - It is probably helpful to know something about what's happening under the covers. The expiration time is associated with the 'self-signature' (of the public primary key by the private primary key). By adding a new self-signature to the key bundle with a later expiration date, clients with the updated bundle should honor the date on the newer self-signature rather than the older one.
 - This update can be performed with the following command:
  gpg --quick-set-expire (fingerprint) (new_expiration_time)
  - This should add that new self-signature described above to the bundle
 - See 'Publish a key bundle to the key server network' above

- If master/primary key expires
 - Clients will now get validation errors since the expiration date is in the past. But the update process should be the same as 'before master/primary key expires'. Follow the same steps described there.

- If master/primary key is compromised
 - Use master/primary key to generate a revocation certificate for itself
  gpg --generate-revocation (fingerprint) > revocation.cert
  - The revocation certificate is detached from the key bundle, in its own file. This step can be done ahead of time if desired, and the revocation certificate file kept in a safe place.
  - To add the revocation certificate to the key bundle:
   gpg --import revocation.cert
   - Your local gpg instance now considers the primary key revoked
  - See 'Publish a key bundle to the key server network' above to propagate the revocation to the rest of the world
