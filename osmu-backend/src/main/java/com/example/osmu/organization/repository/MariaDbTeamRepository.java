package com.example.osmu.organization.repository;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.TeamRecord;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "mariadb")
public class MariaDbTeamRepository implements TeamRepository {

    private final String url;
    private final String username;
    private final String password;
    private volatile boolean schemaReady;

    public MariaDbTeamRepository(
            @Value("${spring.datasource.url}") String url,
            @Value("${spring.datasource.username}") String username,
            @Value("${spring.datasource.password}") String password
    ) {
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public List<TeamRecord> findAll() {
        ensureSchema();
        String sql = """
                SELECT id, organization_id, name, description, created_at, updated_at
                FROM teams
                ORDER BY id
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            List<TeamRecord> teams = new ArrayList<>();
            while (resultSet.next()) {
                teams.add(mapRow(resultSet));
            }
            return teams;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public Optional<TeamRecord> findById(long id) {
        ensureSchema();
        String sql = """
                SELECT id, organization_id, name, description, created_at, updated_at
                FROM teams
                WHERE id = ?
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, id);
            try (ResultSet resultSet = statement.executeQuery()) {
                if (resultSet.next()) {
                    return Optional.of(mapRow(resultSet));
                }
                return Optional.empty();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean existsByOrganizationIdAndName(long organizationId, String name) {
        ensureSchema();
        String sql = "SELECT 1 FROM teams WHERE organization_id = ? AND name = ? LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, organizationId);
            statement.setString(2, name);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public long nextId() {
        ensureSchema();
        String sql = "SELECT COALESCE(MAX(id), 0) + 1 AS next_id FROM teams";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql);
             ResultSet resultSet = statement.executeQuery()) {
            if (resultSet.next()) {
                return resultSet.getLong("next_id");
            }
            return 1L;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public TeamRecord save(TeamRecord team) {
        ensureSchema();
        String sql = """
                INSERT INTO teams
                    (id, organization_id, name, description, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    description = VALUES(description),
                    updated_at = VALUES(updated_at)
                """;
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, team.id());
            statement.setLong(2, team.organizationId());
            statement.setString(3, team.name());
            statement.setString(4, team.description());
            statement.setTimestamp(5, Timestamp.from(team.createdAt().toInstant()));
            statement.setTimestamp(6, Timestamp.from(team.updatedAt().toInstant()));
            statement.executeUpdate();
            return team;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void deleteById(long id) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try (PreparedStatement deleteMembers = connection.prepareStatement("DELETE FROM team_members WHERE team_id = ?");
                 PreparedStatement deleteTeam = connection.prepareStatement("DELETE FROM teams WHERE id = ?")) {
                deleteMembers.setLong(1, id);
                deleteMembers.executeUpdate();
                deleteTeam.setLong(1, id);
                deleteTeam.executeUpdate();
                connection.commit();
            } catch (SQLException exception) {
                connection.rollback();
                throw exception;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public List<Long> findMemberIds(long teamId) {
        ensureSchema();
        String sql = "SELECT user_id FROM team_members WHERE team_id = ? ORDER BY user_id";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, teamId);
            try (ResultSet resultSet = statement.executeQuery()) {
                List<Long> memberIds = new ArrayList<>();
                while (resultSet.next()) {
                    memberIds.add(resultSet.getLong("user_id"));
                }
                return memberIds;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public void replaceMembers(long teamId, List<Long> userIds) {
        ensureSchema();
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try (PreparedStatement deleteStatement = connection.prepareStatement("DELETE FROM team_members WHERE team_id = ?");
                 PreparedStatement insertStatement = connection.prepareStatement("""
                         INSERT INTO team_members (team_id, user_id, created_at)
                         VALUES (?, ?, ?)
                         """)) {
                deleteStatement.setLong(1, teamId);
                deleteStatement.executeUpdate();
                Timestamp now = Timestamp.from(OffsetDateTime.now().toInstant());
                for (Long userId : userIds) {
                    insertStatement.setLong(1, teamId);
                    insertStatement.setLong(2, userId);
                    insertStatement.setTimestamp(3, now);
                    insertStatement.addBatch();
                }
                insertStatement.executeBatch();
                connection.commit();
            } catch (SQLException exception) {
                connection.rollback();
                throw exception;
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean hasMember(long teamId, long userId) {
        ensureSchema();
        String sql = "SELECT 1 FROM team_members WHERE team_id = ? AND user_id = ? LIMIT 1";
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, teamId);
            statement.setLong(2, userId);
            try (ResultSet resultSet = statement.executeQuery()) {
                return resultSet.next();
            }
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    @Override
    public boolean isHealthy() {
        try (Connection connection = connect();
             PreparedStatement statement = connection.prepareStatement("SELECT 1");
             ResultSet resultSet = statement.executeQuery()) {
            return resultSet.next();
        } catch (SQLException exception) {
            return false;
        }
    }

    private synchronized void ensureSchema() {
        if (schemaReady) {
            return;
        }

        try (Connection connection = connect();
             PreparedStatement teamsStatement = connection.prepareStatement("""
                     CREATE TABLE IF NOT EXISTS teams (
                         id BIGINT NOT NULL PRIMARY KEY,
                         organization_id BIGINT NOT NULL,
                         name VARCHAR(100) NOT NULL,
                         description VARCHAR(500),
                         created_at TIMESTAMP NOT NULL,
                         updated_at TIMESTAMP NOT NULL,
                         UNIQUE KEY uk_teams_org_name (organization_id, name),
                         INDEX idx_teams_organization (organization_id)
                     )
                     """);
             PreparedStatement membersStatement = connection.prepareStatement("""
                     CREATE TABLE IF NOT EXISTS team_members (
                         team_id BIGINT NOT NULL,
                         user_id BIGINT NOT NULL,
                         created_at TIMESTAMP NOT NULL,
                         PRIMARY KEY (team_id, user_id),
                         INDEX idx_team_members_user (user_id)
                     )
                     """)) {
            teamsStatement.executeUpdate();
            membersStatement.executeUpdate();
            schemaReady = true;
        } catch (SQLException exception) {
            throw databaseException(exception);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private TeamRecord mapRow(ResultSet resultSet) throws SQLException {
        return new TeamRecord(
                resultSet.getLong("id"),
                resultSet.getLong("organization_id"),
                resultSet.getString("name"),
                resultSet.getString("description") == null ? "" : resultSet.getString("description"),
                resultSet.getTimestamp("created_at").toInstant().atOffset(ZoneOffset.UTC),
                resultSet.getTimestamp("updated_at").toInstant().atOffset(ZoneOffset.UTC)
        );
    }

    private ApiException databaseException(SQLException exception) {
        return new ApiException(ApiErrorCode.INTERNAL_ERROR, "Database operation failed: " + exception.getMessage());
    }
}
