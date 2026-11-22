package com.lyu.poem_quiz

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.widget.Toast

/**
 * 接收 PackageInstaller 的安装结果。
 *
 * 静态注册在 Manifest，因为 commit 后当前进程可能被系统结束，动态注册收不到。
 * 安装失败给出可读原因；成功无需处理——系统安装器会自行提示并拉起新版本。
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE
        )
        if (status == PackageInstaller.STATUS_SUCCESS) return

        // -1 不是失败：STATUS_PENDING_USER_ACTION = -1，STATUS_FAILURE 实际是 1。
        // commit 成功后系统先发这个状态，把安装确认页的 Intent 放在 EXTRA_INTENT 里
        // 等调用方拉起；不拉起它用户就永远看不到确认弹窗。0.4.1 上实测：漏掉这个
        // 分支会误报「安装失败（-1）」，安装流程卡死在这里。
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirmation = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT) as? Intent
            }
            if (confirmation == null) {
                Toast.makeText(context.applicationContext, "未拿到安装确认页，请在应用内重试", Toast.LENGTH_LONG).show()
                return
            }
            try {
                // 用户刚在应用内点了更新，属于前台场景，直接拉起确认页。
                context.startActivity(confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (e: Exception) {
                Toast.makeText(context.applicationContext, "无法弹出安装确认页：${e.message}", Toast.LENGTH_LONG).show()
            }
            return
        }

        val message = when (status) {
            PackageInstaller.STATUS_FAILURE_ABORTED -> "已取消安装"
            PackageInstaller.STATUS_FAILURE_BLOCKED -> "安装被系统阻止，请检查「安装未知应用」权限"
            PackageInstaller.STATUS_FAILURE_CONFLICT -> "安装冲突，请先卸载旧版"
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> "安装包与设备不兼容"
            PackageInstaller.STATUS_FAILURE_INVALID -> "安装包已损坏"
            PackageInstaller.STATUS_FAILURE_STORAGE -> "存储空间不足"
            else -> "安装失败（$status）"
        }
        // 通用失败（STATUS_FAILURE）时系统给的 detail 往往才是真实原因，一并展示。
        val detail = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        Toast.makeText(
            context.applicationContext,
            if (detail.isNullOrEmpty()) message else "$message：$detail",
            Toast.LENGTH_LONG,
        ).show()
    }
}
