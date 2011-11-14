class Array
  def to_hash
    hash = {}
    each { |n| hash[n[0]] = n[1] }
    hash
  end
  
  def subarray_count(subarray) 
    each_cons(subarray.length).count(subarray)
  end
  
  def index_by(&block)
    map(&block).zip(self).to_hash
  end
  
  def occurences_count
    Hash.new(0).merge zip(map { |item| count(item)}).to_hash
  end
end

