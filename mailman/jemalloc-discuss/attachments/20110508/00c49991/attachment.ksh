>From 8f062e5af433ae0948d2f13bc3a5f7172ad4e802 Mon Sep 17 00:00:00 2001
From: Nathan McSween <nwmcsween@gmail.com>
Date: Thu, 28 Apr 2011 19:43:06 +0000
Subject: [PATCH] Makefile.in - test/allocated requires pthread

---
 jemalloc/Makefile.in |    4 ++--
 1 files changed, 2 insertions(+), 2 deletions(-)

diff --git a/jemalloc/Makefile.in b/jemalloc/Makefile.in
index 26da0e2..de7492f 100644
--- a/jemalloc/Makefile.in
+++ b/jemalloc/Makefile.in
@@ -136,9 +136,9 @@ doc: $(DOCS)
 		 @objroot@lib/libjemalloc@install_suffix@.$(SO)
 	@mkdir -p $(@D)
 ifneq (@RPATH@, )
-	$(CC) -o $@ $< @RPATH@@objroot@lib -L@objroot@lib -ljemalloc@install_suffix@
+	$(CC) -o $@ $< @RPATH@@objroot@lib -L@objroot@lib -ljemalloc@install_suffix@ -lpthread
 else
-	$(CC) -o $@ $< -L@objroot@lib -ljemalloc@install_suffix@
+	$(CC) -o $@ $< -L@objroot@lib -ljemalloc@install_suffix@ -lpthread
 endif
 
 install_bin:
-- 
1.7.4.1

