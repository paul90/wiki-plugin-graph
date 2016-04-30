
here = null

escape = (text)->
  return null unless text
  text
    .replace /&/g, '&amp;'
    .replace /</g, '&lt;'
    .replace />/g, '&gt;'

parse = (text) ->
  merge = (arcs, right) ->
    arcs.push right if arcs.indexOf(right) == -1
  graph = {}
  left = op = right = null
  for line in text.split(/\n/)
    tokens = line.trim().split(/\s*(-->|<--|<->)\s*/)
    for token in tokens
      if token == ''
      else if token == '-->' or token == '<--' or token == '<->'
        op = token
      else
        right = if token == 'HERE' then here else token
        graph[right] ||= []
        if left? && op? && right?
          switch op
            when '-->' then merge graph[left], right
            when '<--' then merge graph[right], left
            when '<->' then merge graph[left], right; merge graph[right], left
        left = right
        op = right = null
  graph

place = (graph) ->

  copy = (loc) ->
    [loc[0], loc[1]]

  looping = (node) ->
    for child in graph[node]
      for grand in graph[child]
        return true if node == grand and placed[child]?
        for great in graph[grand]
          return true if node == great and placed[grand]? and placed[child]?
    false

  placed = {}
  origin = [50, 50]
  for name, children of graph
    if not placed[name]
      placed[name] = copy origin
      origin[0] += 100
    node = copy placed[name]
    node[1] += 75
    for child in children
      if not placed[child]
        node[0] += 50 if looping(child)
        placed[child] = copy node
        node[0] += 75
  {graph, placed}

render = ({graph, placed}) ->

  markup = []

  svg = (params, more) ->
    elem 'svg', params, {width:'420px', height:'320px'}, more

  link = (params, more) ->
    elem 'a', params, {}, more

  ellipse = (params, more) ->
    elem 'ellipse', params, {stroke:'#999', 'stroke-width':1}, more

  rect = (params, more) ->
    elem 'rect', params, {}, more

  line = (params) ->
    elem 'line', params, {'stroke-width':6, stroke:'#ccc'}, ->

  text = (params, text) ->
    elem 'text', params, {'text-anchor':'middle', dy:6}, ->
      markup.push text.split(' ')[0]

  elem = (tag, params, extra, more) ->
    markup.push "<#{tag} #{attr params} #{attr extra}>"; more(); markup.push "</#{tag}>"

  title = (text) ->
    markup.push "<title>#{text}</title>"

  attr = (params) ->
    ("#{k}=\"#{v}\"" for k, v of params).join " "

  svg {'viewBox':'0 0 420 320'}, ->
    rect {x: 0, y:0, width:420, height:320, fill:'#eee'}, ->

    for node, [x1, y1] of placed
      for child in graph[node]||[]
        [x2, y2] = placed[child] 
        line {x1, y1, x2, y2}

    for node, [x, y] of placed
      href = "http:/#{wiki.asSlug node}.html"
      {color, synopsis} = neighbor node
      link {'xlink:href':href, 'data-node':escape(node), 'data-synopsis':escape(synopsis)}, ->
        ellipse {cx:x, cy:y, rx:30, ry:20, fill:color}, ->
          title escape node
        text {x,y}, escape node

  markup.join "\n"

neighbor = (title) ->
  wanted = wiki.asSlug title
  return {color: '#ee8'} if title.toLowerCase() == here.toLowerCase()
  for site, query of wiki.neighborhood
    continue if query.sitemapRequestInflight or !query.sitemap
    for {slug, synopsis} in query.sitemap
      return {color: '#8ee', synopsis} if slug == wanted
  return {color: '#8e8'}

emit = ($item, item) ->

  here = $item.parents('.page').find('h1').text().trim()
  $item.append render place parse item.text
  $item.append """<p class="caption"></p>"""

  $item.addClass 'graph-source'
  $item.get(0).graphData = -> parse item.text

bind = ($item, item) ->

  $item.dblclick -> wiki.textEditor $item, item

  $item.find('a').click (e) ->
    e.preventDefault()
    node = $(e.target).parent('a').data('node')
    page = $item.parents '.page' unless e.shiftKey
    wiki.doInternalLink node, page

  $item.find('a').on 'hover', (e) ->
    html = $(e.target).parent('a').data('synopsis')
    $item.find('.caption').html(html)

  $item.on 'drop', (e) ->
    e.preventDefault()
    e.stopPropagation()
    url = e.originalEvent.dataTransfer.getData("URL")
    return unless url
    segs = url.split '/'
    return unless (n = segs.length) >= 5
    console.log 'segs', segs, segs.length
    site = if segs[n-2] == 'view'
      drop = (n-5)/2
      lineup = $('.page').index($item.parents('.page'))
      console.log {n, drop, lineup}
      null
    else
      segs[n-2]
    wiki.pageHandler.get
      pageInformation: {site, slug:segs[n-1]}
      whenNotGotten: -> console.log "Graph drop: Can't parse '#{url}'"
      whenGotten: (pageObject) ->
        item.text += "\nHERE --> #{pageObject.getTitle()}"
        update()

  update = ->
    $item.empty()
    emit($item, item)
    # bind($item, item)
    wiki.pageHandler.put $item.parents('.page:first'),
      type: 'edit',
      id: item.id,
      item: item



window.plugins.graph = {emit, bind} if window?
module.exports = {parse} if module?

