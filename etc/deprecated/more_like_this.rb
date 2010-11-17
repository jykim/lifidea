module Sunspot
  class Setup
    def more_like_this=(fields)
      @more_like_this = fields
    end

    def more_like_this
      @more_like_this || []
    end
  end
end

module Sunspot
  module DSL
    class Fields
      def more_like_this(*names)
        @setup.more_like_this = names
      end
    end
  end
end

module Sunspot
  def self.more_like_this(obj)
    session.more_like_this(obj)
  end
end

module Sunspot
  module Query
    class MoreLikeThis < Query
      def initialize(obj)
        @obj = obj
      end

      def to_params
        setup = Setup.for(@obj.class)
        {
          :q => "id:\"#{Adapters::InstanceAdapter.adapt(@obj).index_id}\"",
          :fl => "*,score",
          # FIXME: Will only text fields be used as the basis for MoreLikeThis queries?
          "mlt.fl" => setup.more_like_this.map { |f| "#{f}_text" }.join(","),
          "mlt.mintf" => 1
        }
      end
    end
  end
end

module Sunspot
  class Session
    def more_like_this(obj)
      setup = Setup.for(obj.class)
      search = Search.new(connection, setup, Query::MoreLikeThis.new(obj), @config)

      def search.execute
        reset
        @solr_result = @connection.mlt(@query.to_params)
        self
      end

      # solr_rsult['response'] is nil if there's no matches
      def search.solr_response
        @solr_response ||= @solr_result['response'] || {'docs' => []}
      end

      search.execute
    end
  end
end

module Sunspot
  module Rails
    module MoreLikeThis

      def more_like_this
        search = Sunspot.more_like_this(self)
        search.hits
      end
    end
  end
end

ActiveRecord::Base.send(:include, Sunspot::Rails::MoreLikeThis)