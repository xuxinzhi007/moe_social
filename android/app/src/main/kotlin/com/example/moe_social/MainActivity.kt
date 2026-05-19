package com.example.moe_social

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Build
import android.widget.Toast

import android.content.Intent
import android.provider.Settings
import android.content.Context

import android.net.Uri
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import java.security.MessageDigest
import java.io.File

class MainActivity : FlutterActivity() {
    private var lastImeIdLogged: String? = null
    private var lastIsAdbLogged: Boolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moe_social/feishu").setMethodCallHandler { call, result ->
            when (call.method) {
                "isInstalled" -> {
                    result.success(isFeishuInstalled())
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moe_social/app_update").setMethodCallHandler { call, result ->
            when (call.method) {
                "compareApkSignatureWithInstalled" -> {
                    val path = call.argument<String>("apkPath")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID", "apkPath required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(compareApkSigningWithInstalled(path))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "requestUninstallCurrentApp" -> {
                    try {
                        val intent = Intent(Intent.ACTION_UNINSTALL_PACKAGE).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openApkContainingFolder" -> {
                    val path = call.argument<String>("apkPath")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID", "apkPath required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(openContainingFolder(path))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }




    }

    private fun isFeishuInstalled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    "com.ss.android.lark",
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo("com.ss.android.lark", 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun compareApkSigningWithInstalled(apkPath: String): Map<String, Any?> {
        val pm = packageManager
        val myPkg = packageName
        val flags = signingFlags()
        val installedPi = try {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(myPkg, flags)
        } catch (_: Exception) {
            return mapOf("match" to false, "error" to "installed_read_fail")
        }
        val apkPi = pm.getPackageArchiveInfo(apkPath, flags)
            ?: return mapOf("match" to false, "error" to "apk_parse_fail")
        apkPi.applicationInfo?.apply {
            sourceDir = apkPath
            publicSourceDir = apkPath
        }

        val apkPkg = apkPi.packageName ?: return mapOf("match" to false, "error" to "apk_parse_fail")
        if (apkPkg != myPkg) {
            return mapOf(
                "match" to false,
                "error" to "package_name_mismatch",
                "installedPackage" to myPkg,
                "apkPackage" to apkPkg,
                "installedVersionName" to installedPi.versionName,
                "apkVersionName" to apkPi.versionName,
                "installedVersionCode" to versionCodeLong(installedPi),
                "apkVersionCode" to versionCodeLong(apkPi),
            )
        }

        val installedSha = firstSignerSha256(installedPi)
        val apkSha = firstSignerSha256(apkPi)
        if (installedSha == null || apkSha == null) {
            return mapOf(
                "match" to false,
                "error" to "cert_unavailable",
                "installedSha256" to installedSha,
                "apkSha256" to apkSha,
            )
        }
        if (installedSha != apkSha) {
            return mapOf(
                "match" to false,
                "error" to "signing_mismatch",
                "installedSha256" to installedSha,
                "apkSha256" to apkSha,
            )
        }
        return mapOf(
            "match" to true,
            "installedSha256" to installedSha,
            "apkSha256" to apkSha,
            "installedPackage" to myPkg,
            "apkPackage" to apkPkg,
            "installedVersionName" to installedPi.versionName,
            "apkVersionName" to apkPi.versionName,
            "installedVersionCode" to versionCodeLong(installedPi),
            "apkVersionCode" to versionCodeLong(apkPi),
        )
    }

    private fun versionCodeLong(pi: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pi.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            pi.versionCode.toLong()
        }
    }

    private fun openContainingFolder(apkPath: String): Boolean {
        val dir = File(apkPath).parentFile ?: return false
        val candidates = listOf(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(dir.absolutePath), "resource/folder")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("content://com.android.externalstorage.documents/root/primary")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
            Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )

        for (intent in candidates) {
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }
        return false
    }

    private fun signingFlags(): Int {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    private fun firstSignerSha256(pi: PackageInfo): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val si = pi.signingInfo ?: return null
                val sigs: Array<Signature> = si.apkContentsSigners
                if (sigs.isEmpty()) return null
                sha256Hex(sigs[0].toByteArray())
            } else {
                @Suppress("DEPRECATION")
                val sigs = pi.signatures ?: return null
                if (sigs.isEmpty()) return null
                sha256Hex(sigs[0].toByteArray())
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun sha256Hex(bytes: ByteArray): String {
        val d = MessageDigest.getInstance("SHA-256").digest(bytes)
        return d.joinToString("") { b -> "%02x".format(b.toInt() and 0xff) }
    }
}
