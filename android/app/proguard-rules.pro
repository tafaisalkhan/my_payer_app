# Room loads WorkManager's generated database implementation by name at runtime.
# R8 otherwise removes its constructor, causing a crash in InitializationProvider.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
