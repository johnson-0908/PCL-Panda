Public Module ModLauncherUpdate
    Private UpdateBusy As Integer = 0
    Public LastUpdateIsNewest As Boolean? = Nothing

    Public Sub ShowLastLauncherUpdateResult()
        Try
            Dim ResultPath = Path.Combine(Paths.Base, "PCL", "Updates", "result.json")
            If Not File.Exists(ResultPath) Then Return
            LauncherUpdate.AssertSafePath(ResultPath)
            Dim Result = JObject.Parse(File.ReadAllText(ResultPath))
            Dim State = CStr(Result("state"))
            If State <> "installed" AndAlso Not If(Result.Value(Of Boolean?)("notified"), False) Then
                Hint("上次更新未完成，请查看 PCL/Updates 中的结果记录；原程序备份已保留。", HintType.Red)
                Result("notified") = True
                File.WriteAllText(ResultPath, Result.ToString())
            End If
        Catch ex As Exception
            Logger.Warn(ex, "读取更新结果失败")
        End Try
    End Sub

    Public Sub CheckForLauncherUpdates(Optional Manual As Boolean = False)
        If Not Manual AndAlso Not Settings.Get(Of Boolean)("RevivedUpdateAutoCheck") Then Return
        If Interlocked.CompareExchange(UpdateBusy, 1, 0) <> 0 Then
            If Manual Then Hint("正在检查或准备更新，请稍候……")
            Return
        End If
        RunInNewThread(
        Sub()
            Try
                Dim Release = LauncherUpdate.CheckLatest()
                If Release Is Nothing Then
                    If Manual Then Hint("本仓库暂时没有可用的正式更新包。")
                    Return
                End If
                LastUpdateIsNewest = Not LauncherUpdate.IsNewer(Release.Version, LauncherUpdate.CurrentVersion)
                If LastUpdateIsNewest.Value Then
                    If Manual Then Hint("当前已是最新版本：" & LauncherUpdate.CurrentVersion, HintType.Green)
                    Return
                End If
                If Not Manual Then
                    '启动时仅一次非模态提示，不下载、不安装、不弹确认窗口。
                    Hint("发现 PCL2复活版 " & Release.Version & "，可在 设置 → 其他 → 检查更新 中安装。")
                    Return
                End If
                If MyMsgBox("当前版本：" & LauncherUpdate.CurrentVersion & vbCrLf &
                            "新版本：" & Release.Version & vbCrLf & vbCrLf & Release.Notes & vbCrLf & vbCrLf &
                            "只更新程序文件，保留账号、设置和游戏。下载完成后会再次询问是否重启。",
                            "发现新版本", "下载更新", "取消", "查看发布页",
                            Button3Action:=Sub() OpenWebsite(Release.PageUrl)) <> 1 Then Return
                If LoaderTaskbar.Any(Function(t) t.State = LoadState.Loading) Then
                    Hint("请先等待启动或下载任务完成，再更新启动器。", HintType.Red)
                    Return
                End If
                Hint("正在下载并校验更新包，请稍候……")
                LauncherUpdate.DownloadAndPrepare(Release, Paths.Base)
                If MyMsgBox("更新包已通过 SHA-256 校验。" & vbCrLf &
                            "现在保存设置并重启安装吗？失败时会尝试恢复旧程序。" & vbCrLf &
                            "选择稍后不会在退出时偷偷安装，可再次点击检查更新。",
                            "更新已就绪", "重启安装", "稍后") <> 1 Then Return
                RunInUiWait(
                Sub()
                    If LoaderTaskbar.Any(Function(t) t.State = LoadState.Loading) OrElse McInstanceLock.IsAnyLocked Then
                        Hint("请先结束游戏、启动或下载任务，再重启安装。", HintType.Red)
                        Return
                    End If
                    ConfigUtils.SaveAll()
                    Logger.Instance.Flush()
                    LauncherUpdate.StartInstaller(Paths.Base, Release.Version)
                    FrmMain.EndProgram(True)
                End Sub)
            Catch ex As Exception
                Logger.Warn(ex, "本仓库更新检查或准备失败；现有程序未更换")
                If Manual Then MyMsgBox("更新未完成，现有程序仍可使用。" & vbCrLf &
                                       "请检查网络后重试；GitHub 限流或不可达时可从本仓库发布页手动下载。" & vbCrLf & vbCrLf &
                                       ex.Message, "更新失败", "确定", "打开发布页",
                                       Button2Action:=Sub() OpenWebsite(LauncherUpdate.ReleasesUrl))
            Finally
                Interlocked.Exchange(UpdateBusy, 0)
            End Try
        End Sub, "PCL2复活版更新", ThreadPriority.BelowNormal)
    End Sub
End Module
