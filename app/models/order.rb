# -*- coding: utf-8 -*-
class Order < ActiveRecord::Base

  belongs_to :shop
  belongs_to :wx_user
  has_many :items, -> { order(id: :desc) }
  has_many :comments, through: :items

  has_one :order_wx_user_address_map
  has_one :wx_user_address, through: :order_wx_user_address_map
  has_one :sale
  has_one :bargain

  attr_accessor :seckill_token

  enum status: [:unpaid, :paid, :delivered, :finished, :expired, :deleted, :received]

  acts_as_messageable

  default_scope { where.not(status: Order.statuses[:deleted]) }
  scope :should_expire, ->(time_edge = 1.day.ago) { unpaid.where("created_at < ?", time_edge) }
  scope :should_received, ->(time_edge = 14.day.ago) { delivered.where("updated_at < ?", time_edge) }
  scope :should_finished, ->(time_edge = 14.day.ago) { received.where("updated_at < ?", time_edge) }
  scope :after_status, -> (status) {
                                     status_val = statuses[status] || status
                                     where("status >= ?",status_val)
                                   }

  scope :in_status, -> (status_list = []) {
                                     status_list_val = status_list.map{|s| statuses[s] || s}
                                     where(status: status_list_val)
                                   }
  scope :after_paid, -> { in_status(%w(paid delivered finished)) }

  scope :direct_sell, -> { where("sources is NULl OR sources = ?", Order.sources[:direct]) }
  scope :agent_sell, -> { where("sources = ?", Order.sources[:agent]) }

  # attr_accessor :payment_type_name, :variants
  attr_accessor :variants, :use_vip_privilege, :use_coupon, :use_points

  validates :amount, presence: true
  validates :sn, presence: true, uniqueness: true
  # validates :amount, format: { with: /\A[+]?[0-9]+(\.[0-9]{1,2})?\z/, message: "订单总金额格式不正确，订单总金额必须为大于等于0的2位小数" }, allow_blank: true
  validates :amount, numericality: { greater_than_or_equal_to: 0, message: "订单总金额必须大于等于0" }
  validates :freight_value, format: { with: /\A[+]?[0-9]+(\.[0-9]{1,2})?\z/, message: "运费格式不正确，运费必须为大于等于0的2位小数" }, allow_blank: true
  # validates :products_amount, format: { with: /\A[+]?[0-9]+(\.[0-9]{1,2})?\z/, message: "商品总金额格式不正确，商品总金额必须为大于等于0的2位小数" }, allow_blank: true
  validates :products_amount, numericality: { greater_than_or_equal_to: 0, message: "商品总金额必须大于等于0" }, allow_blank: true
  #validates_associated :wx_user_address
  validates_presence_of :wx_user

  has_one :payment, -> { order('id DESC') }, as: :payable, class_name: "Payment::Base"
  has_one :shipping, -> { order('id DESC') }



  delegate :phone, :address, to: :wx_user_address, allow_nil: true
  delegate :inventory_available?, to: "self.class"
  delegate :personal_pickup?, to: "shipping", allow_nil: true
  delegate :out_trade_no, :trade_no, to: :payment, allow_nil: true
  delegate :points, to: :shop
  delegate :open_id, to: :wx_user, allow_nil: true

  after_create :set_expired_time, :send_agent_entry_sms, :send_seckill_commit_message
  before_save :update_products_amount, :send_sms, :update_wx_user_order_prompt, :update_delivery_sn
  after_save :send_wx_template_message, :update_status
  after_save :publish_notification

  round_scale :amount, :products_amount, :freight_value

  DeliveryTypeHuman =  {
      ems: "EMS",
      shentong: "申通快递",
      shunfeng: "顺丰速运",
      yuantong: "圆通速递",
      yunda: "韵达快运",
      zhongtong: "中通快递",
      huitongkuaidi: "汇通快运",
      tiantian: "天天快递",
      zhaijisong: "宅急送",
      youzhengguonei: "邮政国内包裹",
      youzhengguoji: "邮政国际包裹",
      emsguoji: "EMS国际快递",
      youshuwuliu: "优速快递",
      quanfengkuaidi: "全峰快递",
      debangwuliu: "德邦物流",
      supplierdefined: "商户配送"
  }

  enum sources: [:direct, :agent, :seckill]

  enum delivery_type: DeliveryTypeHuman.keys

  def sources_name
    I18n.t("order_sources.#{sources}")   
  end

  # the order's amount is 0
  def amount_zero?
    amount.to_f == 0.0
  end  

  def shipping_delivery?
    if shipping.nil?
      true
    else
      shipping.shipping_delivery?
    end
  end

  def delivery_type?
    (delivery_type.blank? && delivery_corp.blank?) || delivery_type.present?
  end

  def delivery_corp_name
    delivery_type? ? delivery_type_human : delivery_corp
  end

  def delivery_type_human
    HashWithIndifferentAccess.new(DeliveryTypeHuman)[delivery_type]
  end

  def support_delivery_api?
    (delivered? || finished?) && delivery_type? && shipping_delivery?
  end

  def delivery_wap_api_url(callback_url = nil)
    URI::encode("http://m.kuaidi100.com/index_all.html?type=#{delivery_type}&postid=#{delivery_sn}&callbackurl=#{callback_url}")
  end

  def delivery_pc_api_url
    URI::encode("http://www.kuaidi100.com/chaxun?com=#{delivery_type}&nu=#{delivery_sn}")
  end

  def show_comment
    comment.present? ? comment : '无'
  end

  def show_sources_name
    sources.present? ? sources_name : "直销"
  end   

  def subject
    items.collect{|item| "#{item.product}"}.join("_").truncate(12)
  end

  def product_names(type = 1)
    {
      '1' => items.collect{|item| "#{item.product}(#{item.quantity.to_i}件)"}.join(",\n"),
      '2' => items.collect{|item| "（#{item.product}），数量#{item.quantity.to_i}件"}.join("，"),
      '3' => items.collect{|item| "（#{item.product}），购买数量：#{item.quantity.to_i}件"}.join("，"),
      '4' => items.collect{|item| "#{item.product}"}.join("，")
    }[type.to_s]
  end

  def product_sns
    items.collect{|item| "#{item.product.try(:sn)}(#{item.quantity.to_i}件)"}.join(",\n")
  end

  def items_count
    # items.count
    items.map(&:quantity).sum
  rescue => e
    logger.error "#{e.message}:#{e.backtrace}"
  end

  def receiver_name
    wx_user_address.try(:name)
  end

  def receiver_phone
    wx_user_address.try(:phone)
  end

  def payment_name
    # payment.try(:payment_type) || payment.try(:body)
    payment.try(:body)
  end

  def logistic_status
    case "#{status}"
      when "delivered", "finished"
        "delivered"
      #when "expired"
      #  "none"
      else
        "undeliver"
    end
  end

  def do_pay!
    self.paid!
    self.update paid_at: DateTime.now
    self.to_print      # 打印机
    self.send_message_of_paid_order
    self.send_igetui_message
    self.mark_as_unread_for_mp_user
    self.send_seckill_paid_message if seckill? #如果是秒杀的订单,生成的支付成功后的通知
  end
  alias :done_pay :do_pay!

  def mark_as_unread_for_mp_user
    $redis.hset "shops:#{self.shop.id}:orders:mp_view_status", self.sn, true
  rescue => e
    logger.error "#{e.message}:#{e.backtrace}"
  end

  def send_seckill_paid_message
    return unless seckill?
    result = EcActivity::Seckill::OrderService.find_token_by_order_sn(sn)
    EcActivity::Seckill::OrderService.paid(result[:token]) if result.present? and result[:token].present?
  end

  def send_sekcill_order_cancel_message
    result = EcActivity::Seckill::OrderService.find_token_by_order_sn(sn)
    EcActivity::Seckill::OrderService.cancel(result[:token]) if result.present? and result[:token].present?
  end

  def do_delivered!
    transaction(requires_new: true) do
      self.delivered!
      self.send_message_of_delivered_order
    end
  end

  def do_finished!
    transaction(requires_new: true) do
      if received?
        self.finished!
        self.send_mq_message('finish')# unless payment.try(:payment_type_id).eql?(10007)
      end
      shop.shop_wx_user_maps.find_or_create_by(wx_user: wx_user)
      self.send_message_of_finished_order
    end
  end

  def do_received!
    self.received! if delivered?
  end

  def send_message_of_paid_order
    shop.send_message_of_paid_order(self, "订单编号：#{sn}，订单金额：#{amount}元")
  end

  def send_message_of_unpaid_order
    shop.send_message_of_unpaid_order(self, "订单编号：#{sn}，订单金额：#{amount}元")
  end

  def send_message_of_finished_order
    shop.send_message_of_finished_order(self, "订单编号：#{sn}，订单金额：#{amount}元")
  end

  def send_message_of_delivered_order
    shop.send_message_of_delivered_order(self, "订单编号：#{sn}，订单金额：#{amount}元")
  end

  def cal_amount
    return products_amount if products_amount.present?
    items.inject(0) {|amount, item| amount += item.price * item.quantity }
  end

  def delivery_freight_value
    return FreightCalculator.new(self).result
    # return freight_value if freight_value.present?
    # params = {products_attributes: {}, province: order_wx_user_address_map.try(:wx_user_address).try(:province), city: order_wx_user_address_map.try(:wx_user_address).try(:city), order_amount: amount}
    # items.each do |item|
    #   params[:products_attributes][item.product_variant.product_id.to_s.to_sym] = item.quantity
    # end
    # freights = [items.collect(&:product_variant).collect(&:product).collect{|p| p.calculate_freight(params[:products_attributes][p.id.to_s.to_sym].to_i, params[:order_amount].to_f, params[:province], params[:city])}].flatten.compact
    # brr = []
    # brr << freights.sum if freights.present?
    # brr << shop.to_money_calculate_freight(params[:order_amount], params[:province], params[:city])
    # brr.compact.min.to_f.round(2)
  end

  def freight_value_from_shop
    if shipping.shipping_delivery?
      return FreightCalculator.new(self).result
      # return delivery_freight_value
    end
    if shipping.personal_pickup?
      return 0.0
    end

    0.0
  end

  def checkin(variants = [])
    variants.each do |variant_hash|
      variant_hash = HashWithIndifferentAccess.new(variant_hash)
      product_variant = shop.variants.find(variant_hash[:product_variant_id])
      item = items.new(
                product_variant: product_variant,
                quantity: variant_hash[:quantity],
                price: product_variant.price,
              )
      item.total_price = item.cal_total_price
    end

    self.amount = cal_amount 
    calculate_deduction_and_amount
    _freight_value = freight_value_from_shop #这样其他价格相关的字段就是折扣后的的
    assign_attributes(freight_value: _freight_value, variants: variants, amount: amount + _freight_value.to_f) #最终赋值
  end

  def save_address(wx_user_address_attr = nil)
    _order_wx_user_address_map = self.order_wx_user_address_map || self.build_order_wx_user_address_map(wx_user_address_id: wx_user_address_attr[:id])
    _order_wx_user_address_map.save

    _wx_user_address = _order_wx_user_address_map.wx_user_address || _order_wx_user_address_map.build_wx_user_address
    _wx_user_address.assign_attributes(wx_user_address_attr)
    _wx_user_address.wx_user = wx_user
    _wx_user_address.save!
    _order_wx_user_address_map.save!
  end

  def request_inventory_for_sell
    ims_items = items.map{|order_item| InventoryCore::OrderInterface::OrderItem.new(order_item.product_variant.sku.to_s, shop.ims_warehouse.id, order_item.quantity) }
    order = InventoryCore::OrderInterface::Order.new sn, 'SELL', ims_items
    result = InventoryCore::OrderInterface.new(shop.ims_client).process_order(order, 'CONFIRM')
    # raise ActiveRecord::Rollback unless result
    raise InventoryError unless result
  end

  def save_variants(variants)
    variants = variants.map{|variant| HashWithIndifferentAccess.new(variant)}
    checkin(variants)
    # items.map(&:request_inventory!)
    request_inventory_for_sell unless seckill?

    variant_ids = variants.collect{|variant| variant[:product_variant_id]}
    wx_user.current_cart_with_shop(shop.id).items.where(product_variant_id: variant_ids).map(&:destroy)
  end

  def bind_shipping(shipping_attr)
    shipping_attr = HashWithIndifferentAccess.new(shipping_attr)
    return unless shipping_attr[:shipping_setting_type]

    _shipping = self.shipping || self.build_shipping
    case shipping_attr[:shipping_setting_type]
      when "ShippingSetting::PersonalPickup"
        _shipping.assign_attributes(shipping_attr)
        _shipping.assign_attributes(subbranch_name: _shipping.subbranch.try(:name))
      when "ShippingSetting::ShippingDelivery"
        _shipping.assign_attributes(shipping_attr)
    end
    _shipping
  end

  # checkout!([{"product_variant_id"=>"3", "quantity"=>"3"}], {})
  def checkout!(variants, wx_user_address)
    transaction(requires_new: true) do
      save_address(wx_user_address)
      save_variants(variants)
      # self.update(wx_user_address: wx_user_address, amount: _amount, status: :unpaid)
      self.save!
    end
  end

  def return_inventory_for_order
    ims_items = items.map{|order_item| InventoryCore::OrderInterface::OrderItem.new(order_item.product_variant.sku.to_s, shop.ims_warehouse.id, order_item.quantity) }
    order = InventoryCore::OrderInterface::Order.new "#{sn}_destroy_#{Random.rand(99)}", 'REJECT', ims_items
    result = InventoryCore::OrderInterface.new(shop.ims_client).process_order(order)
    # raise ActiveRecord::Rollback unless result
    raise InventoryError unless result
  end

  def do_expired!
    transaction(requires_new: true) do
      # items.map(&:returning_inventory!)
      return_inventory_for_order unless seckill?
      self.expired!
      self.send_mq_message('expire')
    end
  end

  def common_pay!
    _option = {
      amount: amount,
      subject: subject,
      payment_type_id: Origin::PaymentType::PaymentNames[payment_type_name],
      body: shop.payment_name_human_with_name(payment_type_name)
    }

    Payment::Base.setup(shop, self, _option)
  end

  def cash_on_delivery!
    _option = {
      amount: amount,
      subject: subject,
      body: shop.payment_name_human_with_name(payment_type_name)
    }

    Payment::CashOnDelivery.setup(shop, self, _option)
  end

  def bargainpay!(new_payment_type_name = "bargainpay")
    _option = {
      amount: amount,
      subject: subject,
      payment_type_id: PaymentType.all_payment_types_hash[new_payment_type_name],
      body: shop.payment_name_human_with_name(new_payment_type_name).presence || new_payment_type_name
    }

    Payment::Bargainpay.setup(shop, self, _option)     
  end  

  def pay!(payment_type_name = nil)
    self.payment_type_name = payment_type_name

    available_names = shop.available_vcooline_payments
    available_names = available_names.reverse_merge PaymentType.names
    raise "NoSupportPaymentType" unless available_names.has_key?(payment_type_name)

    case payment_type_name
      when "tenpay", "wxpay", "yeepay", "alipay", "vip_userpay", 'vcooline_alipay', 'vcooline_yeepay', 'wxpay_v2'
        common_pay!
      when "cash_on_delivery"
        cash_on_delivery!   
      when "bargainpay"       
        bargainpay!
    end
  end

  def change_pay!(new_payment_type_name = nil)
    raise "IllegalityPaymentType" unless self.payment_type_name == "bargainpay"
    # self.update_column("payment_type_name", new_payment_type_name) 此处不需要急着更新支付名称
    bargainpay!(new_payment_type_name)
  end

  def logistic_status_human
    #HashWithIndifferentAccess.new(LogisticStatusHuman)[logistic_status]
    delivery_sn.present? ? '已发货' : '未发货'
  end

  def update_payment_type! current_payment_type_name
    update_column("payment_type_name", current_payment_type_name)
  end 

  def bargainpay?
    payment_type_name == "bargainpay"
  end 

  LogisticStatusHuman =  {
      undeliver: "未发货",
      delivered: "已发货",
  }

  StatusHuman =  {
      unpaid: "待付款",
      paid: "待发货",
      delivered: "待收货",
      finished: "已完成",
      expired: "已过期",
      deleted: "已撤销",
      received: "待评论"
    }

  def status_human
    HashWithIndifferentAccess.new(StatusHuman)[status]
  end

  def sms_attrs
    {
      paid: {
        content: "买家:（#{wx_user_address.try(:name)}）于#{Time.now.strftime("%Y年%m月%d日 %H:%M:%S")}购买了#{product_names(3)}，请尽快处理",
        phone: shop.basic_info_setting.mobile,
      },
      delivered: {
        content: "亲爱的（#{wx_user_address.try(:name)}），您于（#{shop.name}）购买的#{product_names(2)}，已发货。物流公司：（#{delivery_corp_name}），物流单号：（#{delivery_sn}），请注意收货",
        phone: wx_user_address.try(:phone),
      },
      unpaid: {
        content: "#{wx_user_address.try(:name)}，您好：您购买的（#{product_names(4)}），订单编号：#{sn}。交易价格已被卖家修改为\"#{amount}\"元，请确认无误后支付。",
        phone: wx_user_address.try(:phone),
      }
    }
  end

  def is_allow_paid_send_sms?
    self.paid? && self.status_changed? && (shop.present? && wx_user_address.present? && (shop.try(:basic_info_setting) && shop.try(:basic_info_setting).try(:if_may_send_sms, self.status)))
  end

  def is_allow_delivered_send_sms?
    self.delivered? && (self.delivery_type_changed? || self.delivery_corp_changed? || self.delivery_sn_changed?) && (shop.present? && wx_user_address.present? && (shop.try(:basic_info_setting) && shop.try(:basic_info_setting).try(:if_may_send_sms, self.status)))
  end

  def is_allow_received_send_sms?
    false
  end

  def is_allow_unpaid_send_sms?
    self.unpaid? && self.products_amount_changed? && !self.new_record?
  end

  def is_allow_deleted_send_sms?
    false
  end
  def is_allow_finished_send_sms?
    false
  end

  # avoid to raise exception in process_seckill_orders
  def is_allow_expired_send_sms? 
  end

  def send_sms
    return unless send("is_allow_#{self.status}_send_sms?")
    res = HTTParty.post "#{VCOOLINE_BASE_URL}/suppliers/send_message", body: sms_attrs[self.status.to_sym].merge!({operation: '电商', supplier_id: shop.wx_mp_user.origin.supplier_id})
    logger.info "res of sms: #{res}" 
  rescue => e
    logger.info "#{e.message}:#{e.backtrace}"
    {error: '短信通知发送失败'}
  end

  def send_agent_entry_sms 
    if self.agent?
      begin
        url = "#{WSHOP_BASE_URL}/mobile/orders?wx_mp_user_id=#{shop.try(:wx_mp_user).try(:open_id)}&openid=#{wx_user.open_id}&source=4"
        url_short = UrlShortener.new(url).shorten
        res = HTTParty.post "#{VCOOLINE_BASE_URL}/suppliers/send_message", body: {
          operation: '电商', supplier_id: shop.wx_mp_user.origin.supplier_id, phone: wx_user.open_id,
          content: "请点此链接查询订单: #{url_short.present? ? url_short : url}"
        }
        logger.info "res of sms: #{res}"
      rescue => e
        logger.info "#{e.message}:#{e.backtrace}"
        {error: '短信通知发送失败'}
      end
    end
  end

  def send_seckill_commit_message
    return unless seckill? and valid? and sn.present?
    EcActivity::Seckill::OrderService.commit_token(seckill_token,sn)
  end

  def view_products_amount
    products_amount.present? ? products_amount.to_f : amount.to_f - freight_value.to_f
  end

  def update_products_amount
    if self.products_amount.blank?#手动设置商品总额
      self.products_amount = (self.amount.to_f - self.freight_value.to_f).round(2)
      # self.products_amount = (self.cal_amount).round(2)
    else
      #self.amount = self.products_amount.to_f + self.freight_value.to_f #无需重新赋值
    end
  end

  def adjust_amount! products_amount, freight_value
    self.products_amount = products_amount
    self.freight_value = freight_value
    self.amount = products_amount.to_f + freight_value.to_f
    save
  end

  def update_wx_user_order_prompt
    return unless wx_user && shop && self.status_changed? && !self.new_record?
    order_prompt = wx_user.order_prompt || wx_user.build_order_prompt(shop_id: shop_id)
    order_prompt.update("exist_#{self.status}" =>  true) unless order_prompt.send("exist_#{self.status}")
  rescue => e
    {error: '没有这个订单状态的提醒'}
  end

  def real_coupon_deduction
    [coupon_deduction, max_coupon_deduction_money].map(&:to_f).min
  end

  def good_address(join_by = ' ')
    return unless wx_user_address
    [wx_user_address.province, wx_user_address.city, wx_user_address.address].compact.uniq.join(join_by)
  end

  def vip_trade_token
    return unless wx_user
    wx_user.vip_trade_token(shop.wx_mp_user)
  end

  def has_bargain?
    bargain.present?
  end  

  def bargain_amount
    return 0 unless bargain
    bargain.items.sum(:amount)
  end

  class << self
    def expire_unpaid_all
      should_expire.each do |order|
        order.do_expired!
      end
    end

    def mark_received_as_finished
      should_finished.each do |order|
        order.do_finished!
        order.items.each  do |item|
          item.create_default_comment!
        end  
      end
    end

    def mark_delivered_as_received
      should_received.each do |order|
        order.do_received!
      end
    end    

    def inventory_available?(variants = [])
      variants.all? do |variant_hash|
        variant_hash = HashWithIndifferentAccess.new(variant_hash)
        product_variant = ProductVariant.find_by(id: variant_hash[:product_variant_id])
        product_variant.try(:inventory_available?, variant_hash[:quantity].to_i)
      end
    end

    def process_seckill_orders
      t = Time.now
      Order.seckill.unpaid.each do |order|
        if (t - order.created_at).to_i >= 900
          begin
          order.expired!
          order.send_sekcill_order_cancel_message
          rescue => e
            logger.info "--------------#{e}-------------"
          end
        end
      end
    end
  end

  def update_delivery_sn
    self.delivery_sn = self.sn if self.personal_pickup? && self.delivered? && self.delivery_sn.blank?
  end

  def send_wx_template_message
    basic_info_setting = shop.try(:basic_info_setting)
    if status_changed? && basic_info_setting
      # access_token = "qgr_5No_7DIyDa2CLaqqy9xLGtlZFVb02WsZoBsQD1Nr2GHsRuy7Euvj2FOpN9marmakl-QBbrj_L8UTDGf_Dw"
      access_token = shop.wx_mp_user.try(:origin).try(:wx_access_token)
      return false unless access_token.present?

      # open_id = "oblD8jot26QcHZwGc69RWW855Ppg"
      open_id = wx_user.open_id
      if unpaid? && basic_info_setting.order_temp_check?
        # temp_id = "HcDgigV6lMptosBb7vg0mxjtBdKlR6GXKyqfkjjYut4"
        temp_id = basic_info_setting.order_temp_id
        temp_time = basic_info_setting.order_temp_time
        options = order_temp(access_token,temp_id,open_id)
        send_async_wx_template_message("order_temp",options,access_token,sn,temp_time)
      elsif paid? && basic_info_setting.buy_temp_check?
        # temp_id = "kl7-1Z9whlWlWgSN0m5Ae4jKMDf125gJoNCiSjL9EkA"
        temp_id = basic_info_setting.buy_temp_id
        options = buy_temp(access_token,temp_id,open_id)
        send_async_wx_template_message("buy_temp",options,access_token,sn)
      elsif delivered? && basic_info_setting.delivery_temp_check?
        # temp_id = "BkSgU_-6AumNLoV0XOUM0p1j00D46eubjjGThFRmF5g"
        temp_id = basic_info_setting.delivery_temp_id
        options = delivery_temp(access_token,temp_id,open_id)
        send_async_wx_template_message("delivery_temp",options,access_token,sn)
      end
    end
  end

  def update_status
    order_status_redis_key = 'order:status:delivered'
    if delivered? && status_changed?
      job_id = OrderStatusUpdateWorker.perform_at(15.day.from_now, id, 'finish_order')
      $redis.hset(order_status_redis_key, id, job_id)
    elsif finished? || expired? || deleted?
      Sidekiq::Status.unschedule $redis.hget(order_status_redis_key, id)
    end

    $redis.hdel "shops:#{self.shop.id}:orders:mp_view_status", self.sn unless self.paid?
  rescue => e
    logger.error "#{e.message}: #{e.backtrace}"
    nil
  end

  def publish_notification
    OrderPublisher.publish \
      id: id,
      sn: sn,
      changes: changes
  rescue => e
    logger.error "#{e.message}: #{e.backtrace}"
    nil
  end

  def set_expired_time
    self.update_column("expired_at", Time.now + 1.day)
  end

  def send_igetui_message
    params = {
      role: 'supplier',
      role_id: shop.supplier.try(:id),
      token: shop.supplier.try(:auth_token),
      messageable_type: "Ec::Order",
      messageable_id: self.id,
      source: "vcooline_ec",
      message: "您有一笔新的订单, 请尽快处理。"
    }
    res = HTTParty.post "#{API_VCOOLINE_BASE_URL}/v1/igetuis/igetui_app_message", body: params
    logger.info "igetui #{API_VCOOLINE_BASE_URL}/v1/igetuis/igetui_app_message with params #{params.to_s} res: #{res}"
  rescue => e
    logger.error "#{e.message}:#{e.backtrace}"
  end

  def to_print
    target = self
    text = PrintDsl.new do
      newline do
        text_left "\x1C\x21\x7C\x1B\x21\x30\x1B\x61\x31 待发货订单 \x1B\x64\x01\x1B\x40", '0'
      end
      newline do
        text_left "订单编号：", '0'
        text_left "#{target.sn}", '144'
      end
      newline do
        text_left "", '0'
      end
      target.items.each do |item|
        newline do
          text_left "商品名称：", '0'
          text_left "#{item.product_variant.product.name}", '144'
        end
        item.product_variant.option_values.each do |v|
          newline do
            text_left "#{v.option_type.name[0..4]}：", '0'
            text_left "#{v.content}", '144'
          end
        end
        newline do
          text_left "商品单价：", '0'
          text_left "#{item.product_variant.price}", '144'
        end
        newline do
          text_left "商品数量：", '0'
          text_left "#{item.quantity}", '144'
        end
      end
      newline do
        text_left "商品总额：", '0'
        text_left "#{target.products_amount}", '144'
      end
      newline do
        text_left "运费：", '0'
        text_left "#{target.freight_value} ", '144'
      end

      newline do
        text_left "订单总额：", '0'
        text_left "#{target.amount}", '144'
      end

      newline do
        text_left "支付方式：", '0'
        text_left "#{target.shop.payment_name_human_with_name(target.payment_type_name)}", '144'
      end

      newline do
        text_left "配送方式：", '0'
        text_left "#{target.shipping_type_name}", '144'
      end

      newline do
        if target.shipping_delivery?
          text_left "收货人：", '0'
        else
          text_left "提货人："  , '0'
        end
        text_left "#{target.receiver_name}", '144'
      end

      newline do
        text_left "手机号：", '0'
        text_left "#{target.receiver_phone}", '144'
      end
      newline do
        if target.shipping_delivery?
          text_left "收货地址：", '0'
          text_left "#{[target.wx_user_address.province, target.wx_user_address.city, target.wx_user_address.address].compact.uniq.join(' ')}", '144'
        else
          text_left "自提门店：", '0'
          text_left "#{target.shipping.subbranch_name} #{target.shipping.subbranch.try(:origin).try(:address)}", '144'
        end
      end
      newline do
        text_left "下单时间：", '0'
        text_left "#{target.created_at.strftime('%F %T')}", '144'
      end
      newline do
        text_left "支付时间：", '0'
        text_left "#{target.paid_at.try(:strftime,('%F %T'))}", '144'
      end
      newline do
        text_left "备注：", '0'
        text_left "#{target.show_comment}", '144'
      end
    end
    puts "00000"
    puts text.result
    template = Origin::ShopBranchPrintTemplate.where(open_id: target.shop.wx_mp_user.open_id).where(template_type: 4).first
    if template && template.is_open
      template.thermal_printers.each do |printer|
        print_order = Origin::PrintOrder.new(address: printer.no)
        print_order.status = -1
        print_order.content = text.result
        print_order.save
      end
    end
  end

end
