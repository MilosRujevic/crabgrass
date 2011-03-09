module StudentUserExtension
  #def self.included(base)
  # base.instance_eval do

  def self.add_to_class_definition
    lambda do
      serialize_as IntArray, :student_id_cache

      initialized_by :update_membership_cache, :student_id_cache

      alias_method_chain :update_membership_cache, :student
      alias_method_chain :clear_peer_cache_of_my_peers, :student
      alias_method_chain :clear_cache, :student

      has_many :students, :class_name => 'User',
        :finder_sql => 'SELECT users.* FROM users WHERE users.id IN (#{student_id_cache.to_sql})'

      named_scope :students_of, lambda { |user|
        {
          :conditions => ['users.id in (?)', user.student_id_cache]
        }
      }

    end
  end

  module InstanceMethods

    # this updates the member cache like normal but in addition
    # it creates a list of the users students.
    def update_membership_cache_with_student(membership=nil)
      clear_access_cache
      direct, all, admin_for = get_group_ids
      peer = get_peer_ids(direct)
      student = []
      if direct.any?
        Site.find(:all).each do |site|
          # we first check if the user is a teacher on site.
          next unless direct.include?(site.council_id)
          next if (all & site.group_ids).empty?
          real_admin_for = Group.connection.select_values(%Q[
            SELECT groups.id FROM groups
            WHERE groups.id IN (#{(all & site.group_ids).join(',')})
            AND groups.council_id IN (#{direct.join(',')})
          ])
          student += get_peer_ids(real_admin_for)
        end
      end
      update_attributes :version => version+1,
        :direct_group_id_cache => direct,
        :all_group_id_cache    => all,
        :admin_for_group_id_cache    => admin_for,
        :peer_id_cache         => peer,
        :student_id_cache      => student
    end

    def clear_peer_cache_of_my_peers_with_student(membership=nil)
    if peer_id_cache.any?
      self.class.connection.execute(%Q[
          UPDATE users SET peer_id_cache = NULL, student_id_cache = NULL
          WHERE id IN (#{peer_id_cache.join(',')})
        ])
      end
    end

    def clear_cache_with_student
       self.class.connection.execute(%Q[
         UPDATE users SET
         tag_id_cache = NULL, direct_group_id_cache = NULL, foe_id_cache = NULL,
         peer_id_cache = NULL, friend_id_cache = NULL, student_id_cache = NULL,
         all_group_id_cache = NULL, admin_for_group_id_cache = NULL
         WHERE id = #{self.id}
       ])
    end

    def coordinator_of?(user)
      id = user.instance_of?(Integer) ? user : user.id
      student_id_cache.include?(id)
    end

    def is_teacher?
      #self.try(:students) and !self.students.empty?
      return false
      self.direct_member_of?(Group.find(Site.current.council_id))
    end
    #
    # When our membership changes, we need to clear the peer cache of all

  end
end
