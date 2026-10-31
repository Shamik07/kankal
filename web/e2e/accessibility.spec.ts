import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'

test('sign-in and item editor have no WCAG A or AA violations', async ({ page }) => {
  await page.goto('/sign-in')
  await expect(page.getByRole('heading', { name: 'Welcome back' })).toBeVisible()
  await page.keyboard.press('Tab')
  await expect(page.getByRole('link', { name: 'Skip to main content' })).toBeVisible()
  await page.keyboard.press('Enter')
  await expect(page.locator('#main-content')).toBeFocused()
  const signIn = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
  expect(signIn.violations).toEqual([])

  await page.getByLabel('Email address').fill('one@example.test')
  await page.getByRole('textbox', { name: 'Password' }).fill('test-password-one')
  await page.getByRole('button', { name: 'Sign in', exact: true }).click()
  await page.getByRole('button', { name: 'Create item', exact: true }).click()
  await expect(page.getByRole('dialog')).toBeVisible()
  const editor = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
  expect(editor.violations).toEqual([])
})
