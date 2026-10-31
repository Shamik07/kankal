import { useCallback, useEffect, useState, type FormEvent } from 'react'
import type { Item, ItemInput } from '@/api/types'
import { ApiError } from '@/api/types'
import { recordError } from '@/diagnostics/diagnostics'
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { EmptyState, ErrorState, LoadingState } from '@/components/shared/async-state'
import { useAuth, useServices } from '@/app/app-context'

export function ItemsPage() {
  const { items: itemsApi } = useServices()
  const { setSession } = useAuth()
  const failureMessage = useCallback((error: unknown): string => {
    if (error instanceof ApiError && error.code === 'AUTH_REQUIRED') setSession(null)
    return error instanceof ApiError ? error.message : 'Something went wrong. Please try again.'
  }, [setSession])
  const [items, setItems] = useState<Item[]>([])
  const [loading, setLoading] = useState(true)
  const [loadError, setLoadError] = useState('')
  const [notice, setNotice] = useState('')
  const [noticeError, setNoticeError] = useState(false)
  const [editorOpen, setEditorOpen] = useState(false)
  const [editing, setEditing] = useState<Item | null>(null)
  const [saving, setSaving] = useState(false)
  const [formError, setFormError] = useState('')
  const [deleting, setDeleting] = useState<Item | null>(null)
  const [deleteBusy, setDeleteBusy] = useState(false)

  const loadItems = useCallback(async () => {
    setLoading(true)
    setLoadError('')
    try { setItems(await itemsApi.list()) }
    catch (error) {
      setLoadError(failureMessage(error))
      if (!(error instanceof ApiError)) recordError('items.load')
    }
    finally { setLoading(false) }
  }, [itemsApi, failureMessage])

  useEffect(() => { void loadItems() }, [loadItems])
  function openEditor(item: Item | null = null) {
    setEditing(item)
    setFormError('')
    setEditorOpen(true)
  }
  function closeEditor(open: boolean) {
    setEditorOpen(open)
  }

  async function saveItem(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError('')
    const form = new FormData(event.currentTarget)
    const data: ItemInput = { title: String(form.get('title') ?? ''), description: String(form.get('description') ?? '') }
    if (!data.title.trim()) {
      setFormError('Enter an item title.')
      return
    }
    setSaving(true)
    try {
      if (editing) {
        const updated = await itemsApi.update(editing.id, data)
        setItems((current) => current.map((item) => item.id === updated.id ? updated : item))
        setNotice('Item updated successfully.')
      } else {
        const created = await itemsApi.create(data)
        setItems((current) => [created, ...current])
        setNotice('Item created successfully.')
      }
      setNoticeError(false)
      setEditorOpen(false)
    } catch (error) {
      setFormError(failureMessage(error))
      if (!(error instanceof ApiError)) recordError(editing ? 'items.updated' : 'items.created')
    }
    finally { setSaving(false) }
  }

  async function confirmDelete() {
    if (!deleting) return
    setDeleteBusy(true)
    try {
      await itemsApi.delete(deleting.id)
      setItems((current) => current.filter((item) => item.id !== deleting.id))
      setNotice('Item deleted successfully.')
      setNoticeError(false)
      setDeleting(null)
    } catch (error) {
      setNotice(failureMessage(error))
      setNoticeError(true)
      if (!(error instanceof ApiError)) recordError('items.deleted')
      setDeleting(null)
    }
    finally { setDeleteBusy(false) }
  }

  return <section>
    <div className="mb-8 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
      <div><p className="mb-2 text-sm font-medium text-muted-foreground">Your workspace</p><h1 className="text-3xl font-semibold tracking-tight">Items</h1><p className="mt-2 text-muted-foreground">A simple place to keep your working notes.</p></div>
      <Button onClick={() => openEditor()} className="shrink-0" disabled={loading || Boolean(loadError)}>Create item</Button>
    </div>
    {notice && <Alert variant={noticeError ? 'destructive' : 'default'} className="mb-5" role={noticeError ? 'alert' : 'status'}><AlertDescription>{notice}</AlertDescription></Alert>}
    {loading ? <LoadingState label="Getting your workspace ready…" /> : loadError ? <ErrorState title="Items could not be loaded" description={loadError} onRetry={() => void loadItems()} /> : items.length === 0 ? <EmptyState title="Nothing here yet" description="Create an item to get your first note started." action={{ label: 'Create your first item', onClick: () => openEditor() }} /> :
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{items.map((item) => <Card key={item.id} className="flex flex-col">
        <CardHeader><CardTitle className="break-words">{item.title}</CardTitle><CardDescription>Updated {new Date(item.updatedAt).toLocaleDateString()}</CardDescription></CardHeader>
        <CardContent className="flex flex-1 flex-col"><p className="mb-6 flex-1 whitespace-pre-wrap break-words text-sm text-muted-foreground">{item.description || 'No description'}</p><div className="flex gap-2"><Button variant="outline" className="flex-1" onClick={() => openEditor(item)} aria-label={`Edit ${item.title}`}>Edit</Button><Button variant="ghost" className="text-destructive hover:text-destructive" onClick={() => setDeleting(item)} aria-label={`Delete ${item.title}`}>Delete</Button></div></CardContent>
      </Card>)}</div>}

    <Dialog open={editorOpen} onOpenChange={closeEditor}>
      <DialogContent>
        <DialogHeader><DialogTitle>{editing ? 'Edit item' : 'Create an item'}</DialogTitle><DialogDescription>{editing ? 'Update the title or description.' : 'Add a title and an optional description.'}</DialogDescription></DialogHeader>
        <form onSubmit={saveItem} className="space-y-4" noValidate>
          {formError && <Alert variant="destructive" role="alert"><AlertTitle>Could not save item</AlertTitle><AlertDescription>{formError}</AlertDescription></Alert>}
          <div className="space-y-2"><Label htmlFor="item-title">Title</Label><Input id="item-title" name="title" defaultValue={editing?.title ?? ''} required maxLength={120} /></div>
          <div className="space-y-2"><Label htmlFor="item-description">Description</Label><Textarea id="item-description" name="description" defaultValue={editing?.description ?? ''} rows={4} maxLength={2000} /></div>
          <DialogFooter><Button type="button" variant="outline" onClick={() => closeEditor(false)} disabled={saving}>Cancel</Button><Button type="submit" disabled={saving}>{saving ? 'Saving…' : editing ? 'Save changes' : 'Create item'}</Button></DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
    <Dialog open={Boolean(deleting)} onOpenChange={(open) => { if (!open && !deleteBusy) setDeleting(null) }}>
      <DialogContent>
        <DialogHeader><DialogTitle>Delete this item?</DialogTitle><DialogDescription>“{deleting?.title}” will be removed from your workspace.</DialogDescription></DialogHeader>
        <DialogFooter><Button variant="outline" onClick={() => setDeleting(null)} disabled={deleteBusy}>Keep item</Button><Button variant="destructive" onClick={() => void confirmDelete()} disabled={deleteBusy}>{deleteBusy ? 'Deleting…' : 'Delete item'}</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  </section>
}
