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
                    "canInstall" -> {
                        // 是否已允许「安装未知应用」。
                        //
                        // 没授权时 commit() 不会报错，但系统会静默丢弃安装请求，
                        // 用户永远等不到确认弹窗（vivo 上实测）。所以先查这个，
                        // 未授权就直接提示用户去开，而不是让他干等。
                        result.success(canInstallPackages())
                    }
                    "openInstallSettings" -> {
                        try {
                            openInstallPermissionSettings()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("OPEN_SETTINGS_FAIL", e.message, null)
                        }
                    }
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
     * 是否已允许本应用安装 APK。
     *
     * `REQUEST_INSTALL_PACKAGES` 是特殊权限，Manifest 里声明只是「申请」，
     * 实际要用户在系统设置里打开。Android 8 以下该权限默认放开。
     */
    private fun canInstallPackages(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return packageManager.canRequestPackageInstalls()
    }

    /** 打开本应用的「安装未知应用」授权页。 */
    private fun openInstallPermissionSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(
                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                android.net.Uri.parse("package:$packageName"),
            )
        } else {
            Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
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
        // 要求用户在系统弹窗里确认，而不是静默安装（我们没有 INSTALL_PACKAGES 特权）。
        params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
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
            // 这个 PendingIntent 供 PackageInstaller 回填安装结果，系统必须能往里写
            // extras，所以**必须是 MUTABLE**。用 IMMUTABLE 会让 commit() 直接报
            // 「The commit() status receiver should come from a mutable PendingIntent」，
            // 表现为下载完成后装不上（0.3.0 上实测到）。
            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
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
