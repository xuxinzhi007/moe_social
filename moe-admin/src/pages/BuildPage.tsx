import { BuildCacheActions } from '../components/BuildCacheActions'
import { PageHead } from '../ui'
import { useDeploy } from '../context/DeployContext'

export function BuildPage() {
  const { runJob, activeJob } = useDeploy()

  function run(type: string) {
    void runJob(type)
  }

  const displayLog =
    activeJob &&
    (activeJob.type.startsWith('backend_') ||
      activeJob.type.startsWith('flutter_') ||
      activeJob.type === 'env_inspect')
      ? activeJob.log
      : '选择任务后在此显示日志'

  return (
    <>
      <PageHead title="构建流水线" description="本机交叉编译与 Flutter 调试（较慢）" />

      <div className="split">
        <div className="panel">
          <div className="panel-head">
            <h3>后端</h3>
          </div>
          <div className="panel-body btn-row">
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => run('backend_build_linux')}
            >
              编 Linux 二进制
            </button>
            <button
              type="button"
              className="btn btn-mint"
              onClick={() => run('backend_build_local')}
            >
              本机构建
            </button>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => run('env_inspect')}
            >
              环境巡检
            </button>
          </div>
        </div>
        <div className="panel">
          <div className="panel-head">
            <h3>Flutter</h3>
          </div>
          <div className="panel-body btn-row">
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => run('flutter_doctor')}
            >
              flutter doctor
            </button>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => run('flutter_pub_get')}
            >
              pub get
            </button>
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => run('flutter_build_apk')}
            >
              build apk
            </button>
          </div>
        </div>
      </div>

      <BuildCacheActions />

      <div className="panel">
        <div className="panel-head">
          <h3>构建日志</h3>
        </div>
        <div className="panel-body">
          <pre className="log-pre" style={{ maxHeight: 420 }}>
            {displayLog || '—'}
          </pre>
        </div>
      </div>
    </>
  )
}
