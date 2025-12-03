$driver = Start-SeDriver -Browser Chrome 

$driver.url = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=4765445b-32c6-49b0-83e6-1d93765276ca&redirect_uri=https%3A%2F%2Fwww.office.com%2Flandingv2&response_type=code%20id_token&scope=openid%20profile%20https%3A%2F%2Fwww.office.com%2Fv2%2FOfficeHome.All&response_mode=form_post&nonce=638596868180177352.ZDQ2MTQ5MGItZGU4Ni00N2JjLThjYzMtY2M2MmYyYzJlNDY2ZDkxOTRkZGMtZWE1OS00MDQ2LThmZWQtNTVmMmYyNmE4MDE4&ui_locales=ja&mkt=ja&client-request-id=a2f7f8b0-eaad-4fc5-a137-816525d99daa&state=OJqMJs__3Y0zOAOuBcNoSEa15FxCcylEda2uW3ZNTIzXuuZMfRebXAOMiHzFdMUn1VMqUz-32PKnZiz-EBGa0KCnsHieiFpIrQf30JobZsV2OIqbxQNT2pI1DaloombUPvW8GSD02actbrnJL8tYomu1KcksYUHPYGtku_uYJhx8FxNXEE-w2NKpU6uI0rpf2UZN33yJeXbNEu_Y001vhlbMFN2GvogHBW0FVtdTAZEkdGal_1cwPqqJntMSUKVjHm-7jA4L1v9u0Evg00tjHQ&x-client-SKU=ID_NET8_0&x-client-ver=7.5.1.0'
sleep 2
$driver.FindElementByID('i0116').sendKeys("shumamorimoto@gmail.com")
$driver.FindElementById("idSIButton9").click()

sleep 2
$driver.FindElementById('i0118').sendKeys('password')
$driver.FindElementById('idSIButton9').click()

$driver.FindElementById("idBtn_Back").click()