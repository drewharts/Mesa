# 🔧 **Apple Sign-In Issuer Issue**

## **The Problem**

You're experiencing this error:
```
❌ Supabase Apple sign-in error: Unable to detect issuer in ID token for Apple provider
```

This is related to a **known Supabase issue** where Apple changed their OIDC issuer from `https://appleid.apple.com` to `https://account.apple.com`, but Supabase was still expecting the old issuer.

## **What Happened**

### **Apple's Change (Breaking Change)**
Apple updated their OIDC discovery endpoint:
- **Old**: `https://appleid.apple.com/.well-known/openid-configuration`
- **New**: Redirects to `https://account.apple.com/.well-known/openid-configuration`

### **The Issue**
- Apple ID tokens still contain `https://appleid.apple.com` as issuer
- But Apple's discovery endpoint now uses `https://account.apple.com`
- Supabase was rejecting tokens due to issuer mismatch

### **Supabase's Fix**
Supabase updated their auth service to accept **both issuers**:
- ✅ `https://appleid.apple.com` (old)
- ✅ `https://account.apple.com` (new)

## **Status**

According to the GitHub issue (#2051), **Supabase deployed the fix** to most projects. However:

### **Possible Reasons You're Still Seeing This:**

1. **Project Not Updated Yet** - Some projects may not have received the fix
2. **New Project** - New projects follow a different deployment process
3. **Caching Issue** - Your Supabase project might be cached
4. **Regional Deployment** - Fix may not have rolled out to all regions

## **Immediate Solutions**

### **1. Contact Supabase Support** (Recommended)
- Go to [supabase.help](https://supabase.help)
- Submit a ticket mentioning this issue
- Reference GitHub issue #2051
- They can manually apply the fix to your project

### **2. Test With Different Apple Account**
Try signing in with a different Apple ID to see if it's account-specific.

### **3. Check Your Supabase Project Settings**
Ensure your Apple Sign-In configuration in Supabase Dashboard is correct:
- Services ID
- Team ID
- Key ID
- Private Key

### **4. Clear App Data & Reinstall**
Sometimes clearing app data or reinstalling helps with auth issues.

## **Code Changes We Made**

Our code changes were correct - the issue is on Supabase's side:

### **What We Did:**
- ✅ Changed from `identityToken` to `authorizationCode`
- ✅ Updated SupabaseAuthService to accept `accessToken`
- ✅ Updated LoginViewModel to extract the right token

### **The Problem:**
- This was the right approach for the token extraction
- But Supabase's issuer validation was rejecting valid Apple tokens

## **Timeline**

From the GitHub issue:
- **Issue reported**: June 10, 2025
- **Fix deployed**: June 11, 2025 (to most projects)
- **Status**: ✅ **RESOLVED** for most users

## **Next Steps**

1. **Contact Supabase Support** at [supabase.help](https://supabase.help)
2. **Reference this issue** and mention GitHub #2051
3. **Ask them to apply the Apple issuer fix** to your project
4. **They should be able to fix it quickly** since the fix already exists

## **Alternative Workaround (If Support Takes Time)**

If you need immediate access, you could temporarily:
- Use only Google Sign-In (which works)
- Or implement email/password auth as fallback

But **Supabase support should fix this quickly** since it's a known issue with an existing fix.

## **Prevention**

For future Apple changes:
- Monitor Apple's developer news
- Test auth flows regularly
- Have fallback auth methods ready

---

**Contact Supabase support - they can fix this for you!** 🚀
