export type JobStatus = 'pending' | 'running' | 'succeeded' | 'failed' | 'cancelled'

export interface DeployJob {
  id: string
  type: string
  target?: string
  status: JobStatus
  created_at: string
  started_at?: string
  ended_at?: string
  params?: Record<string, string>
  command?: string
  exit_code?: number
  error?: string
  log: string
}

export interface DeployTarget {
  id: string
  label?: string
  kind?: string
  host?: string
  backend_dir?: string
  api_base_url?: string
}

export interface HostInfo {
  platform?: string
  os?: string
  arch?: string
  shell?: string
  docker_version?: string
  compose_cli?: string
  has_make?: boolean
  go_version?: string
  flutter_version?: string
  workspace_root?: string
  backend_dir?: string
  compose_file?: string
}

export interface RemoteCheck {
  ok?: boolean
  message?: string
  backend_dir?: string
  backend_dir_exists?: boolean
  compose_file?: string
  compose_file_exists?: boolean
  compose_rpc_env_ok?: boolean
  config_rpc_endpoints_ok?: boolean
  api_container_rpc_env_ok?: string
  rpc_config_ok?: boolean
  suggested_backend_dir?: string
  compose_candidates?: string[]
  legacy_super_docker_yaml?: boolean
  raw_output?: string
}

export interface DeployConn {
  baseUrl: string
  token: string
  deployTarget: string
}
