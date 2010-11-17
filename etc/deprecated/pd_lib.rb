
COL_TYPES = ['msword','ppt','pdf','lists','html']
FIELD_EMAIL = ['subject','content','to','sent','name','email']
FIELD_ETC = ['title','url','abstract','date','text']
PIDS = ['c0161','c0002','c0141']
PATH_COL = "/Users/lifidea/Documents/Project/dih/pd/"

def get_title_tag(itype)
  if itype == 'lists'
    "#{itype}_subject"
  else
    "#{itype}_title"
  end
end