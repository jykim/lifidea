
class SearchMethod
  def initialize(xvals , yvals , o = {})
    @ymax = o[:ymax] || 1.0
    @ymin = o[:ymin] || 0.0
    @step_size = o[:step_size] || (@ymax - @ymin) / 10
    @cvg_range = o[:cvg_range] || (@step_size / 10)
    @learn_rate = o[:learn_rate] || 1
    @xvals , @yvals , @o = xvals , yvals , o;
  end
end

# Plain grid search over two variables
class GridSearchMethod < SearchMethod
  def initialize(xvals , yvals , o = {})
    super(xvals, yvals, o)
    #@cvg_range = o[:cvg_range] || 0.0001
  end
  
  # get_set(0,1,0.1)
  # -> [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
  def get_set(start, finish, interval)
    cur_val = start; result = []
    while(cur_val < finish)
      result << cur_val
      cur_val += interval
    end
    result
  end
  
  def search(iter_count = 1, o = {})
    results = {}
    #For each value of parameter 1
    set = get_set(@ymin, @ymax, @step_size)
    set.each_with_index do |val_x , i|
      results[val_x] = {}
      set.each_with_thread do |val_y, j|
        results[val_x][val_y] = yield @xvals , [val_x,val_y] , :train, true
      end
    end#each point
    results
  end
end


# Find max perf. configuration of yvals for each of given xval
# - Try golden section search for each xval (http://en.wikipedia.org/wiki/Golden_section_search)
# - Changed into serial search, remembering the value found in previous x point (20080525)
class GoldenSectionSearchMethod < SearchMethod
  GOLDEN_RATIO = 0.381966
  def initialize(xvals , yvals , o = {})
    super(xvals, yvals, o)
    @cvg_range = o[:cvg_range] || 0.1
    @saved_results = {}
  end
  
  #Determine Appropriate Next Point
  def get_next_point(low_ys , high_ys , cur_y)
    #Current point is nearer to high_ys than low_ys
    if cur_y - low_ys.last > high_ys.last - cur_y
      high_ys << cur_y
      return low_ys.last + (cur_y - low_ys.last) * GOLDEN_RATIO
    else
      low_ys << cur_y
      return cur_y + (high_ys.last - cur_y) * GOLDEN_RATIO
    end
  end

  def search(iter_count , o = {})
    results = []
    1.upto(iter_count) do |i|
      results[i] = [] ; @yvals[i] = @yvals[i-1].dup
      #For each point j
      @xvals.each_with_index do |cur_x , j|
        results[i][j] = {} #
        low_ys = [] ; high_ys = [] #lower & higher y points than cur_y
        low_ys << @ymin ; high_ys << @ymax ; k = 0 ; cur_y = -1

        #Iteration until convergence
        while (high_ys.last - low_ys.last) >= @cvg_range
          #Determine the next point to probe
          cur_y = case k
                  when 0 : @ymin
                  when 1 : @ymax
                  when 2 : GOLDEN_RATIO * (@ymax - @ymin) + @ymin
                  else get_next_point( low_ys , high_ys , cur_y ) #GOLDEN_RATIO*2 - GOLDEN_RATIO^2
                  end

          @yvals[i][j] = cur_y
          results[i][j][cur_y] = if @saved_results[@yvals[i].join("_")]
            @saved_results[@yvals[i].join("_")] 
          else
            @saved_results[@yvals[i].join("_")] = yield @xvals , @yvals[i]
          end
          cur_result = "[#{i}][#{j}] lambda[#{cur_y.round_at(3)}] = #{results[i][j][cur_y]}"
          $lgr.info "#{i} #{j} #{cur_y.round_at(5)} #{results[i][j][cur_y]}"

          if k < 2 then k += 1 ; next end
          #low < cur & high < cur
          if results[i][j][low_ys.last] < results[i][j][cur_y] && results[i][j][high_ys.last] < results[i][j][cur_y]
            @yvals[i][j] = cur_y
          #high < cur < low
          elsif results[i][j][low_ys.last] >= results[i][j][cur_y] && results[i][j][high_ys.last] <= results[i][j][cur_y]
            if k > 2
              high_ys << cur_y ; cur_y = low_ys.pop
            end
          #low < cur < high
          elsif results[i][j][low_ys.last] <= results[i][j][cur_y] && results[i][j][high_ys.last] >= results[i][j][cur_y]
            if k > 2
              low_ys << cur_y ; cur_y = high_ys.pop
            end
          #cur < high < low
          elsif results[i][j][high_ys.last] < results[i][j][low_ys.last]
            high_ys << cur_y ; cur_y = low_ys.pop
          #cur < low < high
          elsif results[i][j][low_ys.last] <= results[i][j][high_ys.last]
            low_ys << cur_y ; cur_y = high_ys.pop
          end

          if low_ys.size == 0
            puts "[#{i}][#{j}] reached lower end" ; break        
          elsif high_ys.size == 0
            puts "[#{i}][#{j}] reached upper end" ; break
          end
          puts "#{cur_result} -> #{low_ys.last.round_at(3)} - #{cur_y.round_at(3)} -  #{high_ys.last.round_at(3)}"
          k += 1
        end#while
        @yvals[i][j] = results[i][j].max_pair[0]
      end#each point
    end#iteration
    results
  end
end