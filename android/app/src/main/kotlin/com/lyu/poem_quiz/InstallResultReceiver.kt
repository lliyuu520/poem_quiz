package com.lyu.poem_quiz

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
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

        val message = when (status) {
            PackageInstaller.STATUS_FAILURE_ABORTED -> "已取消安装"
            PackageInstaller.STATUS_FAILURE_BLOCKED -> "安装被系统阻止，请检查「安装未知应用」权限"
            PackageInstaller.STATUS_FAILURE_CONFLICT -> "安装冲突，请先卸载旧版"
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE -> "安装包与设备不兼容"
            PackageInstaller.STATUS_FAILURE_INVALID -> "安装包已损坏"
            PackageInstaller.STATUS_FAILURE_STORAGE -> "存储空间不足"
            else -> "安装失败（$status）"
        }
        Toast.makeText(context.applicationContext, message, Toast.LENGTH_LONG).show()
    }
}
