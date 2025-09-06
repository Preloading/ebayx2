# eBayX2
###### it's squared since it's the second one.

### What is this?
this fixes the ebay 1.7.2 app for old iphones, so you can buy old iphones, on old iphones.

### But why????
Why not?

### How to use
I assume you are already jailbroken.
1. Go to the "Sources" tab
2. Press the "Edit" button in the corner, and add both "http://cydia.skyglow.es" and "http://cydia.preloading.dev"
3. In Skyglow's repo, install AppSync, then reboot your phone.
4. In Preloading's repo, find eBayX2, Scroll down where it shows the full description to "Install eBay 1.7.2 on device." and press it.
5. Go back to Cydia and install eBayX2
6. Enjoy!

### Reddit post?
https://www.reddit.com/r/LegacyJailbreak/comments/1n8qykp/release_ebayx%C2%B2_buy_old_iphones_on_old_iphones/

### Why no iOS 5 & below?
I tried for a solid day, on iOS 3, but no one knows why it can't find NSObject. (how fun!) Create a github issue if you know why.

### Surely the reason why it doesn't work is because of SSL, so using a proxy should fix it.
No. This uses cURL to make requests, since even iOS 6 has SSL problems with eBay. It won't respect proxy settings (probably).

### Newer versions of eBay
Planned, but not for a bit. I have to  backport login from 1.7.2, since it broke in the new version (lol). They also redid the search parsing, meaning most of this is useless.
### iPad?
Don't have one soz.