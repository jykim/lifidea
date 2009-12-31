class StatsController < ApplicationController
  helper Ziya::HtmlHelpers::Charts
  helper Ziya::YamlHelpers::Charts
     
  def index
    @start_at = params[:start_at] || Time.now.advance(:days => -30).to_date.to_s
    @end_at = params[:end_at] || Date.tomorrow.to_s
    @stats = Stat.between(@start_at, @end_at).find_all_by_rid(params[:rid], :order=>'basedate desc')
    respond_to do |format|
      format.html
      format.xml do
        graph = Ziya::Charts::Line.new(nil, "Statistics (#{params[:rid]})")
        #<%= ziya_chart(url_for(:controller=>'stats',:action=>'index', :rid=>params[:rid], :format=>:xml))%>
        graph.add(:axis_category_text, @stats.map(&:basedate))
        graph.add( :theme, 'ddl' )
        @stats.group_by{|s|s.unit}.each do |unit,items|
          graph.add(:series, unit, items.map(&:content))
        end
        render :xml => graph.to_xml
      end
    end
    #@graph = open_flash_chart_object(600,300,"/stats/index/#{params[:rid]}")
  end

  def graph_code
    title = Title.new("MY TITLE")
    bar = BarGlass.new
    bar.set_values([1,2,3,4,5,6,7,8,9])
    chart = OpenFlashChart.new
    chart.set_title(title)
    chart.add_element(bar)
    render :text => chart.to_s
  end
  
  def chart_ofc
    title = Title.new("Statistics (#{params[:rid]})")
    line = Line.new
    stats = Stat.select_by(/#{params[:rid]}/)
    line.set_values(stats.map{|s|s.content.to_i})
    line.colour = '#5E4725'
    chart = OpenFlashChart.new
    chart.set_title(title)
    chart.add_element(line)
    chart.x_axis = stats.map{|s|XAxisLabel.new(s.basedate.to_s(:db),'#0000ff', 20, 'diagonal')}
    render :text => chart.to_s
  end
end
