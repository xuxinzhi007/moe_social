/** RPC 监控仍使用既有 HTML（embed=ops），避免重复实现图表与日志流。 */
export function RpcPage() {
  const src = '/tools/rpc-monitor.html?embed=ops'
  return <iframe className="rpc-frame" src={src} title="RPC 性能监控" />
}
