# name: discourse-auto-activate-users
# about: Skip email verification during user registration by automatically activating users
# version: 1.0.0
# authors: Combined from multiple plugins
# url: https://github.com/yourusername/discourse-auto-activate-users

enabled_site_setting :auto_activate_users_enabled

# 注册前端资源
register_asset 'stylesheets/hide-email-field.scss'

after_initialize do
  if SiteSetting.auto_activate_users_enabled
    Rails.logger.info("Discourse Auto Activate Users: Email verification skipping is enabled.")

    # 方法1：覆盖 UserActivator 类行为，使用 LoginActivator 而不是 EmailActivator
    class ::UserActivator
      alias_method :original_factory, :factory

      def factory
        if !user.active?
          Rails.logger.info("Discourse Auto Activate Users: Skipping EmailActivator, using LoginActivator.")
          LoginActivator
        elsif SiteSetting.must_approve_users?
          Rails.logger.info("Discourse Auto Activate Users: Skipping ApprovalActivator, using LoginActivator.")
          LoginActivator
        else
          # 使用原始的 factory 方法，回退到 Discourse 默认的激活器
          Rails.logger.info("Discourse Auto Activate Users: User already active, using original factory.")
          original_factory
        end
      end
    end

    # 方法2：修改 User 类，阻止创建 email_token
    User.class_eval do
      def create_email_token
        email_tokens.create(email: email) unless SiteSetting.auto_activate_users_enabled
      end
    end

    # 方法3：修改 UsersController，在创建用户时设置 active 为 true
    UsersController.class_eval do
      private

      def modify_user_params(attrs)
        merge_fields = {ip_address: request.ip}
        merge_fields.merge!(active: true) if SiteSetting.auto_activate_users_enabled
        attrs.merge!(merge_fields)
        attrs
      end
    end

    # 方法4：在用户创建时自动激活用户
    module ::DiscourseAutoActivateUsers
      def self.auto_activate_user(user)
        return if user.nil? || user.active?

        Rails.logger.info("Discourse Auto Activate Users: Activating user #{user.id} immediately.")
        user.active = true
        user.approved = true
        user.save!
      end
    end

    # 方法5：使用 before_save 钩子在保存用户前设置 active 为 true
    module UserAutoActiveExtension
      extend ActiveSupport::Concern
      prepended do
        before_save do
          self.active = true if SiteSetting.auto_activate_users_enabled
        end
      end
    end

    reloadable_patch do
      ::User.prepend UserAutoActiveExtension
    end

    # 钩入用户创建事件以立即激活
    on(:user_created) do |user|
      Rails.logger.info("Discourse Auto Activate Users: User created, attempting to activate user #{user.id}.")
      DiscourseAutoActivateUsers.auto_activate_user(user)
    end
    
    # 处理管理员直接邀请用户的情况
    require_dependency 'invite'
    class ::Invite
      alias_method :original_redeem, :redeem
      
      def redeem(user: nil, email: nil, username: nil, name: nil, password: nil, user_custom_fields: nil, ip_address: nil, session: nil, email_token: nil)
        result = original_redeem(user: user, email: email, username: username, name: name, password: password, user_custom_fields: user_custom_fields, ip_address: ip_address, session: session, email_token: email_token)
        
        if SiteSetting.auto_activate_users_enabled && result.success && result.user.present?
          result.user.activate
          result.user.email_tokens.destroy_all
        end
        
        result
      end
    end
    
    # 简化前端代码，避免使用可能有兼容性问题的cookie库
    DiscourseEvent.on(:application_controller_renderer) do |controller|
      if controller.request.path =~ /\/signup/ && SiteSetting.auto_activate_users_enabled
        controller.send(:cookies).permanent[:email] ||= "#{SecureRandom.hex(8)}@example.com"
      end
    end
  else
    Rails.logger.info("Discourse Auto Activate Users: Email verification skipping is disabled.")
  end
end