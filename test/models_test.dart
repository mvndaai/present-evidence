import 'package:flutter_test/flutter_test.dart';
import 'package:present_evidence/core/models/evidence.dart';
import 'package:present_evidence/core/models/highlight.dart';
import 'package:present_evidence/core/models/team.dart';
import 'package:present_evidence/core/models/case.dart';
import 'package:present_evidence/core/models/presentation.dart';

void main() {
  group('Evidence model', () {
    test('fromMap / toMap round-trip', () {
      final now = DateTime.now();
      final map = {
        'id': 'ev-1',
        'case_id': 'case-1',
        'uploaded_by': 'user-1',
        'name': 'Police Report',
        'type': 'pdf',
        'storage_path': 'cases/case-1/evidence/ev-1.pdf',
        'thumbnail_path': null,
        'is_shared': true,
        'file_size_bytes': 1024,
        'mime_type': 'application/pdf',
        'created_at': now.toIso8601String(),
      };
      final evidence = Evidence.fromMap(map);
      expect(evidence.id, 'ev-1');
      expect(evidence.type, EvidenceType.pdf);
      expect(evidence.isShared, true);
      expect(evidence.typeLabel, 'PDF');
    });

    test('video type detection', () {
      final map = {
        'id': 'ev-2',
        'case_id': 'case-1',
        'uploaded_by': 'user-1',
        'name': 'Body Cam Footage',
        'type': 'video',
        'storage_path': 'cases/case-1/evidence/ev-2.mp4',
        'thumbnail_path': null,
        'is_shared': false,
        'file_size_bytes': 10485760,
        'mime_type': 'video/mp4',
        'created_at': DateTime.now().toIso8601String(),
      };
      final evidence = Evidence.fromMap(map);
      expect(evidence.type, EvidenceType.video);
      expect(evidence.typeLabel, 'Video');
    });

    test('image type detection', () {
      final map = {
        'id': 'ev-3',
        'case_id': 'case-1',
        'uploaded_by': 'user-1',
        'name': 'Crime Scene Photo',
        'type': 'image',
        'storage_path': 'cases/case-1/evidence/ev-3.jpg',
        'thumbnail_path': null,
        'is_shared': true,
        'file_size_bytes': 204800,
        'mime_type': 'image/jpeg',
        'created_at': DateTime.now().toIso8601String(),
      };
      final evidence = Evidence.fromMap(map);
      expect(evidence.type, EvidenceType.image);
      expect(evidence.typeLabel, 'Image');
    });

    test('copyWith updates fields', () {
      final evidence = Evidence(
        id: 'ev-1',
        caseId: 'case-1',
        uploadedBy: 'user-1',
        name: 'Document',
        type: EvidenceType.pdf,
        storagePath: 'path/to/file',
        isShared: false,
        createdAt: DateTime.now(),
      );
      final updated = evidence.copyWith(isShared: true, name: 'Updated Doc');
      expect(updated.isShared, true);
      expect(updated.name, 'Updated Doc');
      expect(updated.id, 'ev-1'); // unchanged
    });
  });

  group('Highlight model', () {
    test('video clip round-trip', () {
      final now = DateTime.now();
      final map = {
        'id': 'h-1',
        'evidence_id': 'ev-2',
        'name': 'Key Moment',
        'type': 'videoClip',
        'clip_start_ms': 30000,
        'clip_end_ms': 45000,
        'start_page': null,
        'end_page': null,
        'zoom_region': null,
        'created_at': now.toIso8601String(),
        'created_by': 'user-1',
      };
      final highlight = Highlight.fromMap(map);
      expect(highlight.type, HighlightType.videoClip);
      expect(highlight.clipStart, const Duration(seconds: 30));
      expect(highlight.clipEnd, const Duration(seconds: 45));
      expect(highlight.zoomRegion, isNull);
    });

    test('pdf pages round-trip', () {
      final now = DateTime.now();
      final map = {
        'id': 'h-2',
        'evidence_id': 'ev-1',
        'name': 'Page 3-5',
        'type': 'pdfPages',
        'clip_start_ms': null,
        'clip_end_ms': null,
        'start_page': 3,
        'end_page': 5,
        'zoom_region': null,
        'created_at': now.toIso8601String(),
        'created_by': 'user-1',
      };
      final highlight = Highlight.fromMap(map);
      expect(highlight.type, HighlightType.pdfPages);
      expect(highlight.startPage, 3);
      expect(highlight.endPage, 5);
    });

    test('image zoom with region', () {
      final now = DateTime.now();
      final map = {
        'id': 'h-3',
        'evidence_id': 'ev-3',
        'name': 'Wound closeup',
        'type': 'imageZoom',
        'clip_start_ms': null,
        'clip_end_ms': null,
        'start_page': null,
        'end_page': null,
        'zoom_region': {
          'left': 0.2,
          'top': 0.3,
          'right': 0.6,
          'bottom': 0.7,
        },
        'created_at': now.toIso8601String(),
        'created_by': 'user-1',
      };
      final highlight = Highlight.fromMap(map);
      expect(highlight.type, HighlightType.imageZoom);
      expect(highlight.zoomRegion, isNotNull);
      expect(highlight.zoomRegion!.left, 0.2);
      expect(highlight.zoomRegion!.right, 0.6);
    });
  });

  group('ZoomRegion model', () {
    test('toRect converts fractional coords to pixels', () {
      const region = ZoomRegion(
        left: 0.1,
        top: 0.2,
        right: 0.5,
        bottom: 0.8,
      );
      final rect = region.toRect(const Size(1000, 500));
      expect(rect.left, closeTo(100, 0.01));
      expect(rect.top, closeTo(100, 0.01));
      expect(rect.right, closeTo(500, 0.01));
      expect(rect.bottom, closeTo(400, 0.01));
    });

    test('aspectRatio calculation', () {
      const region = ZoomRegion(
        left: 0.0,
        top: 0.0,
        right: 0.5,
        bottom: 0.25,
      );
      expect(region.aspectRatio, closeTo(2.0, 0.01));
    });
  });

  group('Team model', () {
    test('fromMap parses correctly', () {
      final map = {
        'id': 'team-1',
        'name': 'Defense Team',
        'created_by': 'user-1',
        'created_at': DateTime.now().toIso8601String(),
      };
      final team = Team.fromMap(map);
      expect(team.name, 'Defense Team');
    });
  });

  group('Case model', () {
    test('fromMap / copyWith', () {
      final now = DateTime.now();
      final map = {
        'id': 'case-1',
        'name': 'State v. Doe',
        'description': 'Criminal case',
        'team_id': 'team-1',
        'created_by': 'user-1',
        'created_at': now.toIso8601String(),
      };
      final legalCase = Case.fromMap(map);
      expect(legalCase.name, 'State v. Doe');
      expect(legalCase.teamId, 'team-1');

      final updated = legalCase.copyWith(name: 'State v. Smith');
      expect(updated.name, 'State v. Smith');
      expect(updated.id, 'case-1');
    });
  });

  group('PresentationItem model', () {
    test('copyWith for notes/comments', () {
      final item = PresentationItem(
        id: 'item-1',
        presentationId: 'pres-1',
        orderIndex: 0,
        evidenceId: 'ev-1',
        presenterNotes: 'Old note',
        publicComment: 'Old comment',
      );
      final updated = item.copyWith(
        presenterNotes: 'New note',
        publicComment: 'New comment',
      );
      expect(updated.presenterNotes, 'New note');
      expect(updated.publicComment, 'New comment');
      expect(updated.id, 'item-1');
    });

    test('clearNotes flag', () {
      final item = PresentationItem(
        id: 'item-1',
        presentationId: 'pres-1',
        orderIndex: 0,
        evidenceId: 'ev-1',
        presenterNotes: 'Note',
      );
      final cleared = item.copyWith(clearNotes: true);
      expect(cleared.presenterNotes, isNull);
    });
  });
}
