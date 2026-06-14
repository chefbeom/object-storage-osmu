import assert from 'node:assert/strict'
import test from 'node:test'
import {
  closeConfirmDialogState,
  openConfirmDialogState,
  runConfirmDialogAction,
} from './confirmDialog.js'

test('closeConfirmDialogState cancels without running action', () => {
  let calls = 0
  const dialog = newConfirmDialog()

  openConfirmDialogState(dialog, {
    title: 'Delete object',
    message: 'docs/a.txt will move to trash.',
    confirmLabel: 'Delete',
    action: () => {
      calls += 1
      return true
    },
  })

  assert.equal(dialog.open, true)
  assert.equal(closeConfirmDialogState(dialog), true)
  assert.equal(calls, 0)
  assert.deepEqual(dialog, newConfirmDialog())
})

test('runConfirmDialogAction runs action once and closes on success', async () => {
  let calls = 0
  const dialog = newConfirmDialog()

  openConfirmDialogState(dialog, {
    title: 'Revoke access key',
    message: 'Access Key #42 will be revoked.',
    confirmLabel: 'Revoke',
    action: async () => {
      calls += 1
      return true
    },
  })

  assert.equal(await runConfirmDialogAction(dialog), true)
  assert.equal(calls, 1)
  assert.deepEqual(dialog, newConfirmDialog())
})

test('runConfirmDialogAction keeps dialog open when action returns false', async () => {
  const dialog = newConfirmDialog()

  openConfirmDialogState(dialog, {
    title: 'Delete bucket',
    message: 'bucket will be deleted.',
    confirmLabel: 'Delete',
    action: async () => false,
  })

  assert.equal(await runConfirmDialogAction(dialog), false)
  assert.equal(dialog.open, true)
  assert.equal(dialog.pending, false)
  assert.equal(dialog.title, 'Delete bucket')
})

test('closeConfirmDialogState does not close while pending', () => {
  const dialog = newConfirmDialog()
  openConfirmDialogState(dialog, {
    title: 'Delete object',
    message: 'pending action',
    confirmLabel: 'Delete',
    action: () => true,
  })
  dialog.pending = true

  assert.equal(closeConfirmDialogState(dialog), false)
  assert.equal(dialog.open, true)
  assert.equal(dialog.pending, true)
})

function newConfirmDialog() {
  return {
    open: false,
    title: '',
    message: '',
    confirmLabel: 'Confirm',
    pending: false,
    action: null,
  }
}
