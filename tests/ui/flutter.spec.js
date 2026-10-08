import { test, expect } from '@playwright/test';
import { fixture, ids } from './fixtures.js';
async function open(page, path = '/') {
  await page.goto('/#' + path);
  await page.reload();
  const accessibility = page.locator('flt-semantics-placeholder');
  await accessibility.waitFor({state: 'attached'});
  await accessibility.evaluate(element => element.click());
}
test('Flutter release: desktop catalog and CSP', async ({page}) => {
  await fixture(page);
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.setViewportSize({width:1440,height:1050});
  await open(page);
  await expect(page.getByText('Quỹ đạo cuối cùng', {exact:true})).toBeVisible();
  await page.screenshot({path:'docs/screenshots/flutter-home.png'});
  expect(errors).toEqual([]);
});
test('Flutter release: mobile booking and admin form', async ({page}) => {
  await fixture(page, 'admin');
  await page.setViewportSize({width:390,height:844});
  await open(page, '/booking/' + ids.show);
  await expect(page.getByText('Chọn ghế', {exact:true}).last()).toBeVisible();
  await page.screenshot({path:'docs/screenshots/flutter-seats-mobile.png'});
  await page.setViewportSize({width:1440,height:1050});
  await open(page, '/admin');
  await expect(page.getByText('Quản trị rạp phim', {exact:true})).toBeVisible();
  await page.getByRole('button', {name:'Thêm mới',exact:true}).click();
  await expect(page.getByRole('textbox', {name:'Tên phim',exact:true})).toBeVisible();
  await page.screenshot({path:'docs/screenshots/flutter-admin.png'});
});
