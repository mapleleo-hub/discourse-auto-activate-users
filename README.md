# Discourse 自动激活用户插件

## 简介

"Discourse 自动激活用户"插件允许 Discourse 管理员跳过用户注册过程中的电子邮件验证步骤。安装并启用此插件后，新注册的用户将自动被激活，无需通过电子邮件验证链接进行验证。同时，插件会隐藏注册页面的邮箱输入框，并自动生成随机邮箱地址。

此插件整合了多个类似功能的插件，提供了多种方法来确保用户自动激活，提高了功能的可靠性。

## 功能

- 跳过用户注册过程中的电子邮件验证步骤
- 自动将新注册用户设置为已激活状态
- 确保不创建电子邮件验证令牌（如果启用了自动激活功能）
- 隐藏注册页面的邮箱输入框
- 自动生成随机邮箱地址并存储在cookie中
- 通过多种方法确保用户激活，提高可靠性(特别包含了invite类型的用户)
- 提供站点设置选项，可随时启用或禁用此功能

## 安装

按照 Discourse 官方插件安装教程进行安装：<https://meta.discourse.org/t/install-plugins-in-discourse/19157>

```bash
# 在 Discourse 安装目录下执行
cd /var/discourse

# 编辑 app.yml 文件
./launcher enter app
cd /var/www/discourse

# 将以下行添加到 app.yml 文件的 plugins 部分
- git clone https://github.com/yourusername/discourse-auto-activate-users.git

# 重建 Discourse
./launcher rebuild app
```

> 注意：请将 `yourusername` 替换为实际的 GitHub 用户名或组织名称。

## 配置

1. 安装并重建后，进入 Discourse 管理面板
2. 导航至 设置 > 插件
3. 找到 auto_activate_users_enabled 设置并确认其状态
   - 启用此设置将：
     - 跳过用户注册时的邮件验证步骤
     - 隐藏注册页面的邮箱输入框
     - 自动生成随机邮箱地址
   - 禁用此设置将恢复 Discourse 默认的用户注册和激活流程

插件默认为启用状态，可根据需要在管理面板中调整。

## 工作原理

此插件通过以下几种方式确保用户自动激活：

1. 覆盖 `UserActivator` 类行为，使用 `LoginActivator` 而不是 `EmailActivator`
   - 当用户未激活时，使用 `LoginActivator` 跳过邮箱验证
   - 当需要管理员批准用户时，使用 `LoginActivator` 跳过邮箱验证
   - 在其他情况下（例如用户已经激活），使用原始的激活器，回退到 Discourse 默认的激活流程
2. 修改 `User` 类，阻止创建 email_token
3. 修改 `UsersController`，在创建用户时设置 `active` 为 `true`
4. 在用户创建事件中自动激活用户
5. 使用 `before_save` 钩子在保存用户前设置 `active` 为 `true`
6. 处理管理员直接邀请用户的情况，确保邀请用户也能自动激活
7. 前端实现：
   - 使用 CSS 隐藏注册页面的邮箱输入框
   - 使用 JavaScript 和 cookie 库自动生成随机邮箱地址并存储在 cookie 中

这些方法共同确保了用户在注册后能够自动激活，无需电子邮件验证，同时提供了无缝的用户体验。

## 注意事项

- 启用此插件将绕过电子邮件验证步骤，这可能会增加垃圾注册的风险
- 自动生成的随机邮箱地址仅用于注册流程，不会发送任何邮件到这些地址
- 由于跳过了邮箱验证，用户将无法通过邮箱找回密码，请确保提供其他账号恢复方式
- 建议在启用此插件的同时，考虑使用其他反垃圾措施，如 reCAPTCHA
- 此插件默认为启用状态（在settings.yml中设置），可在管理面板中根据需要启用或禁用

## 许可证

MIT
