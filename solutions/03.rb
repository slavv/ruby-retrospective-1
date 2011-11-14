require 'bigdecimal'
require 'bigdecimal/util'

class Integer
  def ordinal
    sufix = %w{ th st nd rd th th th th th th }
    to_s + (self / 10 == 1 ? 'th' : sufix[self % 10])
  end
end

class Inventory
  attr_reader :products, :coupons

  def initialize
    @products = []
    @coupons = []
  end
  
  def register(name, price, promotion = {})
    if @products.detect { |product| product.name == name }
      raise "This product already exists in inventory" 
    end
    @products << Product.new(name, price, Promotion.for(promotion))
  end
  
  def register_coupon(name, props)
    @coupons << Coupon.for(name, props)
  end
  
  def [](name)
    @products.detect { |product| product.name == name } or
    raise "No such product in inventory."
  end

  def coupon(name)
    @coupons.detect { |coupon| coupon.name == name } or
      raise "No such coupon in inventory."
  end
  
  def new_cart
    Cart.new self
  end
end

class Product
  attr_reader :name, :promotion
  
  def initialize(name, price, promotion)
    validate name, price.to_d
    @name, @price, @promotion = name, price.to_d, promotion
  end
	 
  def discount(quantity)
    @promotion.discount @price, quantity
  end
  
  def price(quantity)
    @price * quantity
  end
  
  def discounted_price(quantity)
     price(quantity) - discount(quantity)
  end	 
  
  def validate(name, price)
    raise "Product name is too long" if name.length > 40
    raise "Product price is not valid" if not price.between?(0.01, 999.99)
  end
end

module Promotion
  def self.promotion_class(promotion_type)
    case promotion_type
      when :get_one_free then GetOneFree 
      when :package then Package
      when :threshold then Threshold
      else NilPromotion
    end
  end
    
  def self.for(promotion_map = {})
    promotion_type, promotion_args = promotion_map.flatten
    promotion_class(promotion_type).new(promotion_args)
  end
  
  class GetOneFree
    def initialize(promotion_params)
      @product_count = promotion_params
    end
    
    def discount(price, quantity)
      (quantity / @product_count) * price
    end
    
    def name 
      "buy #{@product_count - 1}, get 1 free"
    end
  end

  class Package
    def initialize(promotion_params)
      @product_count, @percents_discount = promotion_params.flatten
    end
    
    def discount(price, quantity)
      discount_per_package = price * @product_count * @percents_discount / 100
      (quantity / @product_count) * discount_per_package
    end
    
    def name
      "get #{@percents_discount}% off for every #{@product_count}"
    end
  end

  class Threshold
    def initialize(promotion_params)
      @product_count, @percents_discount = promotion_params.flatten
    end
    
    def discount(price, quantity)
      discounted_quantity = [quantity - @product_count, '0'.to_d].max
      discounted_quantity * price * @percents_discount / 100
    end
    
    def name
      "#{@percents_discount}% off of every after the #{@product_count.ordinal}"
    end
  end

  class NilPromotion
    def discount(price, quantity)
      0
    end
    
    def name
      ''
    end
  end
end

module Coupon
  def self.coupon_class(coupon_type)
    case coupon_type
      when :percent then PercentCoupon
      when :amount then AmountCoupon
      else NilCoupon
    end
  end
  
  def self.for(name = '', coupon_map = {})
    coupon_type, coupon_param = coupon_map.flatten
    coupon_class(coupon_type).new(name, coupon_param)
  end
  
  class PercentCoupon
    attr_reader :name
  
    def initialize(name, percent)
      @name = name
      @percent = percent
    end
    
    def discount(total) 
      @percent / ("100".to_d) * total 
    end
    
    def print 
       "Coupon %s - %d%% off" % [@name, @percent]
    end
  end

  class AmountCoupon
    attr_reader :name
    
    def initialize(name, amount)
      @name = name
      @amount = amount.to_d
    end
    
    def discount(total) 
      [total, @amount].min
    end
    
    def print
      "Coupon %s - %.2f off" % [@name, @amount]
    end
  end

  class NilCoupon
    attr_reader :name
  
    def initialize(name, args)
    end
    
    def discount(total) 
      0
    end
    
    def print 
      ''
    end
  end
end

class CartItem
  attr_reader :quantity

  def initialize(product)
    @product = product
    @quantity = 0
  end   
  
  def increase(quantity)
    raise "Invalid product count." unless quantity.between? 1, 99
    @quantity += quantity
  end
  
  def discounted_price
    @product.discounted_price @quantity
  end
  
  def price
    @product.price @quantity
  end
  
  def discount
    @product.discount @quantity
  end
  
  def promotion_name
    @product.promotion.name
  end
  
  def name
    @product.name
  end
  
  def discounted?
    discount != 0
  end
end

class Cart
  attr_reader :cart_items, :coupon
  
  def initialize(inventory)
    @inventory = inventory
    @cart_items = []
    @coupon = Coupon.for
  end
  
  def add(product_name, quantity = 1)
    cart_item = @cart_items.detect { |item| item.name == product_name } 
    unless cart_item
      cart_item = CartItem.new(@inventory[product_name])
      @cart_items << cart_item
    end
    cart_item.increase quantity
  end
  
  def use(coupon_name)
    @coupon = @inventory.coupon(coupon_name)
  end
  
  def discount
    @coupon.discount(clear_total)
  end
  
  def discounted?
    @coupon.discount(clear_total).nonzero?
  end
  
  def clear_total
    @cart_items.map{ |cart_item| cart_item.discounted_price }.inject(:+)
	end
  
  def total
    clear_total - discount
  end
  
  def invoice
    BillFormatter.new(self).print_bill
  end
end

class BillFormatter
  def initialize(cart)
    @cart = cart
  end
  
  def print_bill
    @output = ""
    print_border
    print "Name", "qty", "price"
    print_products
    print "TOTAL", "", amount(@cart.total)
    print_border
    @output
  end
  
  def print_border
    @output << "+%s+%s+\n" % ["-" * 48, "-" * 10]
  end
  
  def print_products
    print_border
    @cart.cart_items.each { |item| print_item item }
    if @cart.discounted?
      print @cart.coupon.print, "", amount(-1 * @cart.discount)
    end
    print_border
  end
  
  def print_item(item)
    print item.name, item.quantity, amount(item.price)
    if item.discounted?
      print "  (#{item.promotion_name})", "", amount(-1 * item.discount)
    end
  end
  
  def print(*args)
    @output << "| %-40s %5s | %8s |\n" % args
  end
  
  def amount(decimal)
    "%5.2f" % decimal
  end
end