export function openConfirmDialogState(dialog, { title, message, confirmLabel = 'Confirm', action = null }) {
  Object.assign(dialog, {
    open: true,
    title,
    message,
    confirmLabel,
    pending: false,
    action,
  })
}

export function closeConfirmDialogState(dialog) {
  if (dialog.pending) {
    return false
  }
  Object.assign(dialog, {
    open: false,
    title: '',
    message: '',
    confirmLabel: 'Confirm',
    pending: false,
    action: null,
  })
  return true
}

export async function runConfirmDialogAction(dialog) {
  if (!dialog.action) {
    closeConfirmDialogState(dialog)
    return true
  }

  dialog.pending = true
  const action = dialog.action
  try {
    const shouldClose = await action()
    dialog.pending = false
    if (shouldClose !== false) {
      closeConfirmDialogState(dialog)
      return true
    }
    return false
  } catch (error) {
    dialog.pending = false
    throw error
  }
}
