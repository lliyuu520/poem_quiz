package com.lyu.poem_quiz

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "poem_quiz/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> {
                        val pm = applicationContext.packageManager
                        val info = pm.getPackageInfo(packageName, 0)
                        result.success(
                            mapOf<String, Any>(
                                "code" to if (Build.VERSION.SDK_INT >= 28)
                                    info.longVersionCode.toInt() else info.versionCode,
                                "name" to (info.versionName ?: ""),
                            )
                        )
                    }
                    "cacheDir" -> result.success(cacheDir.absolutePath)
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("BAD_ARGS", "missing path", null)
                        } else {
                            try {
                                installApk(File(path))
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("INSTALL_FAIL", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 用 PackageInstaller 安装缓存目录里的 APK。
     *
     * targetSdk 36（Android 16）下，ACTION_VIEW + package-archive MIME 已被系统禁止，
     * 必须走 PackageInstaller session：把 APK 字节流写进 session，commit 后系统会
     * 弹出安装确认页。不需要 REQUEST_INSTALL_PACKAGES 权限，也不需要 FileProvider。
     *
     * 安装结果由 [InstallResultReceiver] 通过广播接收（在 Manifest 静态注册，
     * 进程被系统安装器结束后仍能收到）。
     */
    @SuppressLint("MissingPermission")
    private fun installApk(apkFile: File) {
        require(apkFile.exists()) { "安装包不存在" }
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        try {
            FileInputStream(apkFile).use { input ->
                session.openWrite("poem_quiz_update", 0, apkFile.length()).use { output ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n <= 0) break
                        output.write(buf, 0, n)
                    }
                    session.fsync(output)
                }
            }
            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            val intent = Intent(applicationContext, InstallResultReceiver::class.java)
            val pending = PendingIntent.getBroadcast(
                applicationContext, sessionId, intent, flags
            )
            session.commit(pending.intentSender)
        } finally {
            session.close()
        }
    }
}
