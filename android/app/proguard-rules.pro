# Flutter ProGuard Rules
# Keep the PathUtils class if it exists (for legacy plugins)
-keep class io.flutter.util.PathUtils { *; }

# Also keep other common Flutter embedding classes that might be stripped
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
