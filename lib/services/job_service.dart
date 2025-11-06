import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/job_model.dart';
import '../utils/app_logger.dart';
import 'api_service.dart';

class JobService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Check if user can post a job (24-hour limit)
  Future<Map<String, dynamic>> canUserPost() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/can-post'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to check posting eligibility');
      }
    } catch (e) {
      throw Exception('Error checking posting eligibility: $e');
    }
  }

  // Create job posting
  Future<Job> createJob(Map<String, dynamic> jobData) async {
    try {
      final headers = await _getHeaders();

      // Log the request for debugging
      if (kDebugMode) {
        print('📤 Creating job with data: ${jsonEncode(jobData)}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/jobs'),
        headers: headers,
        body: jsonEncode(jobData),
      );

      if (kDebugMode) {
        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body: ${response.body}');
      }

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Job.fromJson(data['data']);
      } else if (response.statusCode == 429) {
        // 24-hour limit exceeded
        final data = jsonDecode(response.body);
        throw Exception(
            data['message'] ?? 'You can only post one job every 24 hours');
      } else if (response.statusCode == 400) {
        // Validation error
        final data = jsonDecode(response.body);
        if (data['errors'] != null && data['errors'] is List) {
          final errors = (data['errors'] as List)
              .map((e) => e['msg'] ?? e.toString())
              .join(', ');
          throw Exception('Validation error: $errors');
        }
        throw Exception(data['message'] ?? 'Invalid job data');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to create job posting');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating job: $e');
      }
      throw Exception('Error creating job: $e');
    }
  }

  // Get all jobs with filters
  Future<List<Job>> getJobs({
    int page = 1,
    int limit = 20,
    String? search,
    String? jobType,
    String? location,
    String? tags,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (jobType != null && jobType.isNotEmpty) 'jobType': jobType,
        if (location != null && location.isNotEmpty) 'location': location,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      };

      final uri =
          Uri.parse('$baseUrl/jobs').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List jobsJson = data['data']['jobs'];
        return jobsJson.map((j) => Job.fromJson(j)).toList();
      } else if (response.statusCode == 400) {
        // Handle validation errors gracefully
        AppLogger.w('Jobs fetch validation error: ${response.body}');
        return []; // Return empty list instead of throwing
      } else {
        AppLogger.e(
            'Jobs fetch error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch jobs');
      }
    } catch (e) {
      AppLogger.e('Error fetching jobs: $e', error: e);
      throw Exception('Error fetching jobs: $e');
    }
  }

  // Get my posted jobs
  Future<List<Job>> getMyJobs({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/mine?page=$page&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List jobsJson = data['data']['jobs'];
        return jobsJson.map((j) => Job.fromJson(j)).toList();
      } else {
        throw Exception('Failed to fetch your jobs');
      }
    } catch (e) {
      throw Exception('Error fetching your jobs: $e');
    }
  }

  // Get job by ID
  Future<Job> getJob(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/$jobId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Job.fromJson(data['data']);
      } else {
        throw Exception('Failed to fetch job');
      }
    } catch (e) {
      throw Exception('Error fetching job: $e');
    }
  }

  // Update job
  Future<Job> updateJob(String jobId, Map<String, dynamic> jobData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/jobs/$jobId'),
        headers: headers,
        body: jsonEncode(jobData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Job.fromJson(data['data']);
      } else {
        throw Exception('Failed to update job');
      }
    } catch (e) {
      throw Exception('Error updating job: $e');
    }
  }

  // Delete job
  Future<void> deleteJob(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/jobs/$jobId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete job');
      }
    } catch (e) {
      throw Exception('Error deleting job: $e');
    }
  }

  // Toggle job active status
  Future<Job> toggleJobActive(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/jobs/$jobId/toggle-active'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Job.fromJson(data['data']);
      } else {
        throw Exception('Failed to toggle job status');
      }
    } catch (e) {
      throw Exception('Error toggling job status: $e');
    }
  }

  // Search jobs with advanced filters
  Future<Map<String, dynamic>> searchJobs({
    required String query,
    String? jobType,
    String? location,
    List<String>? tags,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = {
        'q': query,
        'page': page.toString(),
        'limit': limit.toString(),
        if (jobType != null && jobType.isNotEmpty) 'jobType': jobType,
        if (location != null && location.isNotEmpty) 'location': location,
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      };

      final uri = Uri.parse('$baseUrl/jobs/search')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching jobs: $e');
    }
  }

  // Get saved/bookmarked jobs for user
  Future<List<Job>> getSavedJobs({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/saved?page=$page&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List jobsJson = data['data']['jobs'] ?? [];
        return jobsJson.map((j) => Job.fromJson(j)).toList();
      } else {
        throw Exception('Failed to fetch saved jobs');
      }
    } catch (e) {
      throw Exception('Error fetching saved jobs: $e');
    }
  }

  // Save/bookmark a job
  Future<Map<String, dynamic>> saveJob(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/jobs/$jobId/save'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to save job');
      }
    } catch (e) {
      throw Exception('Error saving job: $e');
    }
  }

  // Unsave/remove bookmark
  Future<Map<String, dynamic>> unsaveJob(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/jobs/$jobId/save'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to unsave job');
      }
    } catch (e) {
      throw Exception('Error unsaving job: $e');
    }
  }

  // Check if job is saved by user
  Future<bool> isJobSaved(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/$jobId/is-saved'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['isSaved'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get job applications (for job poster only)
  Future<List<Map<String, dynamic>>> getJobApplications(
    String jobId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/$jobId/applications?page=$page&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List appJson = data['data']['applications'] ?? [];
        return appJson.map((a) => a as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch applications');
      }
    } catch (e) {
      throw Exception('Error fetching applications: $e');
    }
  }

  // Track job view (increment view count)
  Future<void> trackJobView(String jobId) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('$baseUrl/jobs/$jobId/track-view'),
        headers: headers,
      );
    } catch (e) {
      // Silent fail - don't disrupt UX for tracking
      if (kDebugMode) {
        print('❌ Error tracking view: $e');
      }
    }
  }

  // Apply to a job
  Future<Map<String, dynamic>> applyToJob(String jobId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/jobs/$jobId/apply'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Application submitted successfully',
        };
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Cannot apply to this job');
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'You are not authorized to apply');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to apply to job');
      }
    } catch (e) {
      AppLogger.e('Error applying to job: $e', error: e);
      throw Exception('Error applying to job: $e');
    }
  }
}
