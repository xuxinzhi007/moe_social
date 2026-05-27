import { useCallback, useEffect, useState } from 'react'
import { DataEnvBar } from '../components/DataEnvBar'
import { PageInsightStrip } from '../components/PageInsightStrip'
import { PageTabs } from '../components/PageTabs'
import { useAdminAuth } from '../context/AdminAuthContext'
import { DeployApiError } from '../api/deployClient'

type Tab = 'vip' | 'gift'

const ORDER_TABS: { key: Tab; label: string; hint: string }[] = [
  { key: 'vip', label: 'VIP 订单', hint: '订阅与会员' },
  { key: 'gift', label: '礼物购买', hint: '虚拟礼物订单' },
]

export function WalletOrdersPage() {
  const { client } = useAdminAuth()
  const [tab, setTab] = useState<Tab>('vip')
  const [page, setPage] = useState(1)
  const [userId, setUserId] = useState('')
  const [keyword, setKeyword] = useState('')
  const [filterUser, setFilterUser] = useState('')
  const [filterKw, setFilterKw] = useState('')
  const [vipItems, setVipItems] = useState<Array<Record<string, string | number>>>([])
  const [giftItems, setGiftItems] = useState<Array<Record<string, string | number>>>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const pageSize = 20

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      if (tab === 'vip') {
        const res = await client.listVipOrders({
          page,
          page_size: pageSize,
          user_id: filterUser || undefined,
          keyword: filterKw || undefined,
        })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          setVipItems([])
          setTotal(0)
          return
        }
        setVipItems(res.data.items as unknown as Array<Record<string, string | number>>)
        setTotal(res.data.total)
      } else {
        const res = await client.listGiftPurchaseOrders({
          page,
          page_size: pageSize,
          user_id: filterUser || undefined,
          keyword: filterKw || undefined,
        })
        if (!res.success || !res.data) {
          setError(res.message || '加载失败')
          setGiftItems([])
          setTotal(0)
          return
        }
        setGiftItems(res.data.items as unknown as Array<Record<string, string | number>>)
        setTotal(res.data.total)
      }
    } catch (e) {
      setError(e instanceof DeployApiError ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }, [client, tab, page, filterUser, filterKw])

  useEffect(() => {
    void load()
  }, [load])

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <>
      <div className="page-head page-head-row">
        <div>
          <h2>钱包与订单</h2>
          <p className="muted">VIP 订阅与礼物购买订单（只读查询）</p>
        </div>
      </div>
      <DataEnvBar />
      <PageTabs
        tabs={ORDER_TABS}
        active={tab}
        onChange={(next) => {
          setTab(next)
          setPage(1)
        }}
      />
      <PageInsightStrip items={[{ label: '匹配结果', value: loading ? '…' : total }]} />
      <div className="panel">
        <form
          className="inline-form"
          onSubmit={(e) => {
            e.preventDefault()
            setPage(1)
            setFilterUser(userId.trim())
            setFilterKw(keyword.trim())
          }}
        >
          <input placeholder="用户 ID" value={userId} onChange={(e) => setUserId(e.target.value)} />
          <input placeholder="订单号 / 礼物名" value={keyword} onChange={(e) => setKeyword(e.target.value)} />
          <button type="submit" className="btn btn-primary">
            筛选
          </button>
        </form>
        {error ? <p className="text-danger">{error}</p> : null}
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              {tab === 'vip' ? (
                <tr>
                  <th>订单号</th>
                  <th>用户</th>
                  <th>套餐</th>
                  <th>金额</th>
                  <th>状态</th>
                  <th>时间</th>
                </tr>
              ) : (
                <tr>
                  <th>订单号</th>
                  <th>用户</th>
                  <th>礼物</th>
                  <th>数量</th>
                  <th>金额</th>
                  <th>状态</th>
                  <th>时间</th>
                </tr>
              )}
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} className="muted">
                    加载中…
                  </td>
                </tr>
              ) : tab === 'vip' ? (
                vipItems.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="muted">
                      暂无订单
                    </td>
                  </tr>
                ) : (
                  vipItems.map((row) => (
                    <tr key={String(row.id)}>
                      <td>{row.order_no}</td>
                      <td>{row.user_id}</td>
                      <td>{row.plan_name}</td>
                      <td>¥{Number(row.amount).toFixed(2)}</td>
                      <td>{row.status}</td>
                      <td>{row.created_at}</td>
                    </tr>
                  ))
                )
              ) : giftItems.length === 0 ? (
                <tr>
                  <td colSpan={7} className="muted">
                    暂无订单
                  </td>
                </tr>
              ) : (
                giftItems.map((row) => (
                  <tr key={String(row.id)}>
                    <td>{row.order_no}</td>
                    <td>{row.user_id}</td>
                    <td>{row.gift_name}</td>
                    <td>{row.quantity}</td>
                    <td>{row.total_amount}</td>
                    <td>{row.status}</td>
                    <td>{row.created_at}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        {totalPages > 1 ? (
          <div className="pager">
            <button type="button" className="btn btn-ghost" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              上一页
            </button>
            <span className="muted">
              {page}/{totalPages} · 共 {total} 条
            </span>
            <button type="button" className="btn btn-ghost" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              下一页
            </button>
          </div>
        ) : null}
      </div>
    </>
  )
}
