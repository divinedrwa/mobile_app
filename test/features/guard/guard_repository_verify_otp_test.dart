import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:divine_app/features/guard/data/repositories/guard_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late GuardRepository repo;

  setUp(() {
    dio = MockDio();
    repo = GuardRepository(dio: dio);
    registerFallbackValue(RequestOptions(path: '/'));
  });

  group('GuardRepository.verifyVisitorOtp', () {
    test('returns payload on 200', () async {
      when(
        () => dio.post(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/'),
          data: {'verified': true, 'message': 'OTP verified'},
        ),
      );

      final r = await repo.verifyVisitorOtp(otp: '123456', villaId: 'villa_1');

      expect(r['verified'], true);
      expect(r['message'], 'OTP verified');
      verify(() => dio.post(any(), data: any(named: 'data'))).called(1);
    });

    test('returns JSON body on error when verified key present', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 404,
            data: {'verified': false, 'message': 'OTP not found'},
          ),
        ),
      );

      final r = await repo.verifyVisitorOtp(otp: '0000', villaId: 'villa_1');

      expect(r['verified'], false);
      expect(r['message'], 'OTP not found');
    });

    test('throws when error body has no verified flag', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 500,
            data: {'error': 'internal'},
          ),
        ),
      );

      expect(
        repo.verifyVisitorOtp(otp: '1', villaId: 'x'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('GuardRepository.approveVisitorEntry', () {
    test('returns payload on admit success', () async {
      when(
        () => dio.post(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/'),
          data: {
            'admitted': true,
            'verified': true,
            'message': 'Visitor admitted and checked in',
          },
        ),
      );

      final r = await repo.approveVisitorEntry(
        otp: '1234',
        villaId: 'villa_1',
        visitorName: 'Rahul',
        visitorPhone: '9999999999',
      );

      expect(r['admitted'], true);
      expect(r['verified'], true);
    });

    test('returns API payload on functional reject (409/400)', () async {
      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 409,
            data: {
              'admitted': false,
              'verified': false,
              'message': 'OTP already used',
            },
          ),
        ),
      );

      final r = await repo.approveVisitorEntry(
        otp: '1234',
        villaId: 'villa_1',
      );

      expect(r['admitted'], false);
      expect(r['message'], 'OTP already used');
    });
  });
}
