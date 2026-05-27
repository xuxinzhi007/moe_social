import type { ReactNode } from 'react'
import { DataEnvBar } from '../components/DataEnvBar'
import { PageInsightStrip } from '../components/PageInsightStrip'
import { PageTabs, type PageTabItem } from '../components/PageTabs'
import type { ListPageMetric } from './ListPageLayout'
import { PageHead } from './PageHead'

type TabbedPageLayoutProps<T extends string> = {
  title: string
  description?: ReactNode
  envNote?: string
  metrics?: ListPageMetric[]
  headActions?: ReactNode
  tabs: PageTabItem<T>[]
  activeTab: T
  onTabChange: (tab: T) => void
  children: ReactNode
}

/** Tab 工作台页标准骨架（原型 B） */
export function TabbedPageLayout<T extends string>({
  title,
  description,
  envNote,
  metrics,
  headActions,
  tabs,
  activeTab,
  onTabChange,
  children,
}: TabbedPageLayoutProps<T>) {
  return (
    <>
      <PageHead title={title} description={description} actions={headActions} />
      {envNote ? <DataEnvBar note={envNote} /> : null}
      {metrics && metrics.length > 0 ? <PageInsightStrip items={metrics} /> : null}
      <PageTabs tabs={tabs} active={activeTab} onChange={onTabChange} />
      {children}
    </>
  )
}
