# Examples of manual testing of fetch-verify-repo script

# Setup: Local testing environment
# Assumes: test server with root access, import-gpg already run, GPG key imported with ultimate trust

# Step 1: Create a test commit and sign it
cd ~/spasm-ansible
git checkout -b test-release
echo "# Test version" >> README.md
git add README.md
git commit -S -m "Test: bump version for testing"

# Step 2: Create an annotated, signed tag (required format)
git tag -s -m "Test release v0.0.1-test" v0.0.1-test
# Verify tag is annotated and signed
git tag -v v0.0.1-test  # Should show "Good signature"
git cat-file -p v0.0.1-test | grep -E "^(object|type|tag|gpgsig)"  # Verify annotated

# Step 3: Push to remote
git push origin test-release
git push origin v0.0.1-test

# Step 4: On test server, verify current state
cd ~/spasm-ansible
git describe --tags --exact-match  # Should show current tag (if any)
cat /var/lib/spasm-ansible/version  # Should show installed version (if any)

# Step 5: Test script with specific tag (dry-run by checking logs)
bash fetch-verify-repo --tag v0.0.1-test
# Expected output in /var/log/spasm-ansible/fetch-verify-repo.log:
#   "Selected annotated tag: v0.0.1-test"
#   "✓ Tag signature valid"
#   "✓ Tag signer is ultimately trusted"
#   "✓ Commit signature valid"
#   "✓ Commit signer is ultimately trusted"
#   "✓ Post-swap integrity verified"
#   "✓ Stored installed version: v0.0.1-test"

# Step 6: Verify swap succeeded
git describe --tags --exact-match  # Should now show v0.0.1-test
cat /var/lib/spasm-ansible/version  # Should show v0.0.1-test

# Step 7: Test idempotency (should skip if already at tag)
bash fetch-verify-repo --tag v0.0.1-test
# Expected in logs: "Production repo already at v0.0.1-test, skipping"

# Step 8: Test downgrade rejection (create older tag and try to apply)
git tag -s -m "Older release v0.0.0" v0.0.0
git push origin v0.0.0
bash fetch-verify-repo --tag v0.0.0
# Expected in logs: "Downgrade rejected: target v0.0.0 < installed v0.0.1-test"

# Step 9: Test with latest tag (no --tag specified)
git tag -s -m "Latest release v0.0.2" v0.0.2
git push origin v0.0.2
bash fetch-verify-repo
# Expected in logs: "Selected annotated tag: v0.0.2"
# Should auto-select v0.0.2 (latest by semver)

# Step 10: Test failure scenario (simulate broken tag)
# Create lightweight tag (should be rejected)
git tag v0.0.3-lightweight  # No -s flag, no message
git push origin v0.0.3-lightweight
bash fetch-verify-repo --tag v0.0.3-lightweight
# Expected in logs: "Tag v0.0.3-lightweight is not an annotated tag object"

# Step 11: Check logs for all details
tail -100 /var/log/spasm-ansible/fetch-verify-repo.log

# Step 12: Test as admin via sudo (if admin account exists)
sudo -u admin bash fetch-verify-repo --tag v0.0.2
# Should use admin's keyring (~/.gnupg) and succeed if key imported with ultimate trust

# Cleanup: Remove test tags and branches
git tag -d v0.0.0 v0.0.1-test v0.0.2 v0.0.3-lightweight
git branch -D test-release
git push origin --delete v0.0.0 v0.0.1-test v0.0.2 v0.0.3-lightweight test-release
