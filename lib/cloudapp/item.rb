module CloudApp
  
  # An ActiveResource-like interface through which to interract with CloudApp items.
  #
  # @example Gets started by Authenticating
  #   CloudApp.authenticate "username", "password"
  #
  # @example Usage via the Item class
  #   # Find a single item by it's slug
  #   @item = CloudApp::Item.find "2wr4"
  #   
  #   # Get a list of all items
  #   @items = CloudApp::Item.all
  #   
  #   # Create a new bookmark
  #   @item = CloudApp::Item.create :bookmark, :name => "CloudApp", :redirect_url => "http://getcloudapp.com"
  #   
  #   # Create multiple bookmarks
  #   bookmarks = [
  #     { :name => "Authur Dent", :redirect_url => "http://en.wikipedia.org/wiki/Arthur_Dent" },
  #     { :name => "Zaphod Beeblebrox", :redirect_url => "http://en.wikipedia.org/wiki/Zaphod_Beeblebrox" }
  #   ]
  #   @items = CloudApp::Item.create :bookmarks, bookmarks
  #   
  #   # Upload a file
  #   @item = CloudApp::Item.create :upload, :file => "/path/to/image.png"
  #   @item = CloudApp::Item.create :upload, :file => "/path/to/image.png", :private => true
  #   
  #   # Rename a file
  #   CloudApp::Item.update "http://my.cl.ly/items/1912565", :name => "Big Screenshot"
  #   
  #   # Set an items privacy
  #   CloudApp::Item.update "http://my.cl.ly/items/1912565", :private => true
  #   
  #   # Delete an item
  #   CloudApp::Item.delete "http://my.cl.ly/items/1912565"
  #
  #   # Recover a deleted item
  #   CloudApp::Item.recover "http://my.cl.ly/items/1912565"
  #
  # @example Usage via the class instance
  #   # Rename a file
  #   @item.update :name => "Big Screenshot"
  #   
  #   # Set an items privacy
  #   @item.update :private => true
  #   
  #   # Delete an item
  #   @item.delete
  #
  #   # Recover a deleted item
  #   @item.recover
  #
  class Item < Base
    
    # Get metadata about a cl.ly URL like name, type, or view count.
    #
    # Finds the item by it's slug id, for example "2wr4".
    #
    # @param [String] id cl.ly slug id
    # @return [CloudApp::Item]
    def self.find(id)
      res = get "http://cl.ly/#{id}"
      res.ok? ? Item.new(res) : res
    end
    
    # Page through your items.
    #
    # Requires authentication.
    #
    # @param [Hash] opts options parameters
    # @option opts [Integer] :page Page number starting at 1
    # @option opts [Integer] :per_page Number of items per page
    # @option opts [String] :type Filter items by type (image, bookmark, text, archive, audio, video, or unknown)
    # @option opts [Boolean] :deleted Show trashed items
    # @return [Array[CloudApp::Item]]
    def self.all(opts = {})
      res = get "/items", {:query => (opts.empty? ? nil : opts), :digest_auth => @@auth}
      res.ok? ? res.collect{|i| Item.new(i)} : res
    end
    
    # Create a new cl.ly item. Multiple bookmarks can be created at once by
    # passing an array of bookmark options parameters.
    #
    # Requires authentication.
    #
    # @param [Symbol] kind type of cl.ly item (can be +:bookmark+, +:bookmarks+ or +:upload+)
    # @overload self.create(:bookmark, opts = {})
    #   @param [Hash] opts options paramaters
    #   @option opts [String] :name Name of bookmark (only required for +:bookmark+ kind)
    #   @option opts [String] :redirect_url Redirect URL (only required for +:bookmark+ kind)
    # @overload self.create(:bookmarks, bookmarks)
    #   @param [Array] bookmarks array of bookmark option parameters (containing +:name+ and +:redirect_url+)
    # @overload self.create(:upload, opts = {})
    #   @param [Hash] opts options paramaters
    #   @option opts [String] :file Path to file (only required for +:upload+ kind)
    #   @option opts [Boolean] :private override the account default privacy setting
    # @return [CloudApp::Item]
    def self.create(kind, opts = {})
      case kind
      when :bookmark
        res = post "/items", {:body => {:item => opts}, :digest_auth => @@auth}
      when :bookmarks
        res = post "/items", {:body => {:items => opts}, :digest_auth => @@auth}
      when :upload
        r = get "/items/new", {:query => ({:item => {:private => opts[:private]}} if opts.has_key?(:private)), :digest_auth => @@auth}
        return r unless r.ok?
        res = post r['url'], Multipart.new(r['params'].merge!(:file => File.new(opts[:file]))).payload.merge!(:digest_auth => @@auth)
      else
        # TODO raise an error
        return false
      end
      res.ok? ? (res.is_a?(Array) ? res.collect{|i| Item.new(i)} : Item.new(res)) : res
    end
    
    # Modify a cl.ly item. Can currently modify it's name or security setting by passing parameters.
    #
    # Requires authentication.
    #
    # @param [String] href href attribute of cl.ly item
    # @param [Hash] opts item parameters
    # @option opts [String] :name for renaming the item
    # @option opts [Boolean] :privacy set item privacy
    # @return [CloudApp::Item]
    def self.update(href, opts = {})
      res = put href, {:body => {:item => opts}, :digest_auth => @@auth}
      res.ok? ? Item.new(res) : res
    end
    
    # Send an item to the trash.
    #
    # Requires authentication.
    #
    # @param [String] href href attribute of cl.ly item
    # @return [CloudApp::Item]
    def self.delete(href)
      # Use delete on the Base class to avoid recursion
      res = Base.delete href, :digest_auth => @@auth
      res.ok? ? Item.new(res) : res
    end
    
    # Recover an item in the trash.
    #
    # Requires authentication.
    #
    # @param [String] href href attribute of cl.ly item
    # @return [CloudApp::Item]
    def self.recover(href)
      res = put href, {:body => {:deleted => true, :item => {:deleted_at => nil}}, :digest_auth => @@auth}
      res.ok? ? Item.new(res) : res
    end
    
    attr_reader :href, :name, :private, :url, :content_url, :item_type, :view_counter,
                :icon, :remote_url, :redirect_url, :created_at, :updated_at, :deleted_at
    
    # Create a new CloudApp::Item object.
    #
    # Only used internally.
    #
    # @param [Hash] attributes
    # @param [CloudApp::Item]
    def initialize(attributes = {})
      load(attributes)
    end
    
    # Modify the item. Can currently modify it's name or security setting by passing parameters.
    #
    # @param [Hash] opts item parameters
    # @option opts [String] :name for renaming the item
    # @option opts [Boolean] :privacy set item privacy
    # @return [CloudApp::Item]
    def update(opts = {})
      self.class.update self.href, opts
    end
    
    # Send the item to the trash.
    #
    # @return [CloudApp::Item]
    def delete
      self.class.delete self.href
    end
    
    # Recover the item from the trash.
    #
    # @return [CloudApp::Item]
    def recover
      self.class.recover self.href
    end
        
  end
  
end